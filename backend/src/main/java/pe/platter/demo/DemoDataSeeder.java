package pe.platter.demo;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.billing.domain.Plan;
import pe.platter.catalog.application.MenuCatalogQuery;
import pe.platter.catalog.application.PhotoService;
import pe.platter.catalog.domain.Dish;
import pe.platter.catalog.domain.DishDetails;
import pe.platter.catalog.infrastructure.DishRepository;
import pe.platter.iam.domain.UserAccount;
import pe.platter.iam.infrastructure.UserAccountRepository;
import pe.platter.restaurants.domain.DiningTable;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.restaurants.infrastructure.DiningTableRepository;
import pe.platter.restaurants.infrastructure.RestaurantRepository;
import pe.platter.shared.config.PlatterProperties;

/**
 * Restaurante de demostración para la landing ({@code /m/demo}) y para mostrar el panel.
 * Credenciales: demo@platter.pe / demo12345. Se desactiva con {@code platter.demo.enabled=false}.
 *
 * <p>Es idempotente: si el demo ya existe pero tiene una carta antigua (sin fotos o con menos platos), la reconstruye;
 * completa las mesas que falten y, con {@code platter.demo.history=true}, renueva en segundo plano las métricas
 * de ejemplo cuando quedaron desactualizadas.
 */
@Component
@ConditionalOnProperty(name = "platter.demo.enabled", havingValue = "true", matchIfMissing = true)
class DemoDataSeeder implements ApplicationRunner {

    static final String DEMO_EMAIL = "demo@platter.pe";
    static final String DEMO_TABLE_TOKEN = "demo";
    static final String DEMO_TABLE_LABEL = "Mesa Demo";
    static final String DEMO_NAME = "Sabores de Barranco";
    static final String DEMO_ADDRESS = "Av. Grau 123, Barranco, Lima";
    static final String DEMO_OWNER = "Lucía Quispe";
    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final UserAccountRepository users;
    private final RestaurantRepository restaurants;
    private final DiningTableRepository tables;
    private final DishRepository dishes;
    private final PhotoService photos;
    private final ModelLibrary models;
    private final PasswordEncoder passwordEncoder;
    private final TransactionTemplate tx;
    private final CacheManager caches;
    private final DemoHistoryGenerator history;
    private final boolean historyEnabled;

    DemoDataSeeder(UserAccountRepository users, RestaurantRepository restaurants, DiningTableRepository tables,
            DishRepository dishes, PhotoService photos, ModelLibrary models, PasswordEncoder passwordEncoder,
            TransactionTemplate tx, CacheManager caches, DemoHistoryGenerator history, PlatterProperties properties) {
        this.users = users;
        this.restaurants = restaurants;
        this.tables = tables;
        this.dishes = dishes;
        this.photos = photos;
        this.models = models;
        this.passwordEncoder = passwordEncoder;
        this.tx = tx;
        this.caches = caches;
        this.history = history;
        this.historyEnabled = properties.demo().history();
    }

    @Override
    public void run(ApplicationArguments args) {
        UUID restaurantId = tx.execute(status -> seed());
        if (restaurantId == null) {
            return;
        }
        Cache menuCache = caches.getCache(MenuCatalogQuery.CACHE);
        if (menuCache != null) {
            menuCache.evict(restaurantId);
        }
        if (historyEnabled) {
            // En segundo plano: no retrasa el arranque ni el health check.
            Thread.ofVirtual().name("demo-history").start(() -> {
                try {
                    history.refreshIfStale(restaurantId);
                } catch (RuntimeException e) {
                    log.warn("No se pudieron generar las métricas demo: {}", e.getMessage());
                }
            });
        }
    }

    private UUID seed() {
        UUID restaurantId = users.findByEmailIgnoreCase(DEMO_EMAIL).map(UserAccount::getRestaurantId)
                .orElseGet(this::createRestaurant);
        ensureTables(restaurantId);
        List<Dish> current = dishes.findByRestaurantIdOrderByCategoryAscNameAsc(restaurantId);
        boolean outdated = current.size() < DemoMenu.ITEMS.size() + 1
                || current.stream().filter(d -> d.getPhotoId() == null).count() > 1;
        if (outdated) {
            dishes.deleteAll(current);
            dishes.flush();
            restaurants.findById(restaurantId).ifPresent(r -> r.updateProfile(DEMO_NAME, DEMO_ADDRESS));
            users.findByEmailIgnoreCase(DEMO_EMAIL).ifPresent(u -> u.rename(DEMO_OWNER));
            createMenu(restaurantId);
            log.info("Carta demo creada: {} / demo12345 · carta en /m/{}", DEMO_EMAIL, DEMO_TABLE_TOKEN);
        }
        return restaurantId;
    }

    private UUID createRestaurant() {
        Restaurant restaurant = restaurants.save(new Restaurant(DEMO_NAME, DEMO_ADDRESS, Plan.CRECIMIENTO));
        users.save(new UserAccount(restaurant.getId(), DEMO_OWNER, DEMO_EMAIL, passwordEncoder.encode("demo12345")));
        return restaurant.getId();
    }

    private void ensureTables(UUID restaurantId) {
        if (tables.findByToken(DEMO_TABLE_TOKEN).isEmpty()) {
            tables.save(new DiningTable(restaurantId, DEMO_TABLE_LABEL, DEMO_TABLE_TOKEN));
        }
        for (String label : DemoMenu.TABLES) {
            if (!tables.existsByRestaurantIdAndLabelIgnoreCase(restaurantId, label)) {
                DiningTable table = new DiningTable(restaurantId, label);
                table.setActive(!DemoMenu.INACTIVE_TABLE.equals(label));
                tables.save(table);
            }
        }
    }

    private void createMenu(UUID restaurantId) {
        Map<String, UUID> uploaded = new HashMap<>();
        for (DemoMenu.Item item : DemoMenu.ITEMS) {
            save(restaurantId, item, uploaded);
        }
        save(restaurantId, DemoMenu.DRAFT, uploaded);
    }

    private void save(UUID restaurantId, DemoMenu.Item item, Map<String, UUID> uploaded) {
        DishDetails details = item.details();
        if (details.modelId() != null && !models.exists(details.modelId())) {
            details = details.withModelId(models.suggest(details.name(), details.category()).orElse(null));
        }
        if (item.photo() != null) {
            UUID photoId = uploaded.computeIfAbsent(item.photo(), key -> uploadPhoto(restaurantId, key));
            details = details.withPhotoId(photoId);
        }
        Dish dish = new Dish(restaurantId, details);
        if (item.published()) {
            dish.publish();
        }
        dish.changeAvailability(item.available());
        dishes.save(dish);
    }

    private UUID uploadPhoto(UUID restaurantId, String key) {
        ClassPathResource resource = new ClassPathResource("demo/photos/" + key + ".jpg");
        if (!resource.exists()) {
            log.warn("Foto demo {} no encontrada", key);
            return null;
        }
        try {
            return photos.upload(restaurantId, resource.getContentAsByteArray()).getId();
        } catch (IOException e) {
            log.warn("No se pudo leer la foto demo {}: {}", key, e.getMessage());
            return null;
        }
    }
}
