package pe.platter.demo;

import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.billing.domain.Plan;
import pe.platter.catalog.domain.Allergen;
import pe.platter.catalog.domain.Dish;
import pe.platter.catalog.domain.DishDetails;
import pe.platter.catalog.infrastructure.DishRepository;
import pe.platter.iam.domain.UserAccount;
import pe.platter.iam.infrastructure.UserAccountRepository;
import pe.platter.restaurants.domain.DiningTable;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.restaurants.infrastructure.DiningTableRepository;
import pe.platter.restaurants.infrastructure.RestaurantRepository;

/**
 * Restaurante de demostración para la landing ({@code /m/demo}) y pruebas manuales.
 * Credenciales: demo@platter.pe / demo12345. Se desactiva con {@code platter.demo.enabled=false}.
 */
@Component
@ConditionalOnProperty(name = "platter.demo.enabled", havingValue = "true", matchIfMissing = true)
class DemoDataSeeder implements ApplicationRunner {

    static final String DEMO_EMAIL = "demo@platter.pe";
    static final String DEMO_TABLE_TOKEN = "demo";
    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final UserAccountRepository users;
    private final RestaurantRepository restaurants;
    private final DiningTableRepository tables;
    private final DishRepository dishes;
    private final ModelLibrary models;
    private final PasswordEncoder passwordEncoder;

    DemoDataSeeder(UserAccountRepository users, RestaurantRepository restaurants, DiningTableRepository tables,
            DishRepository dishes, ModelLibrary models, PasswordEncoder passwordEncoder) {
        this.users = users;
        this.restaurants = restaurants;
        this.tables = tables;
        this.dishes = dishes;
        this.models = models;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (users.existsByEmailIgnoreCase(DEMO_EMAIL)) {
            return;
        }
        Restaurant restaurant = restaurants.save(
                new Restaurant("Sabores de Barranco (Demo)", "Av. Grau 123, Barranco, Lima", Plan.CRECIMIENTO));
        UUID rid = restaurant.getId();
        users.save(new UserAccount(rid, "Cuenta Demo", DEMO_EMAIL, passwordEncoder.encode("demo12345")));
        tables.save(new DiningTable(rid, "Mesa Demo", DEMO_TABLE_TOKEN));
        for (int n = 1; n <= 4; n++) {
            tables.save(new DiningTable(rid, "Mesa " + n));
        }
        for (DishDetails details : menu()) {
            if (details.modelId() != null && !models.exists(details.modelId())) {
                details = details.withModelId(models.suggest(details.name(), details.category()).orElse(null));
            }
            Dish dish = new Dish(rid, details);
            dish.publish();
            dishes.save(dish);
        }
        log.info("Restaurante demo creado: {} / demo12345 · carta en /m/{}", DEMO_EMAIL, DEMO_TABLE_TOKEN);
    }

    private static List<DishDetails> menu() {
        return List.of(
                dish("Cebiche clásico", "Ceviches", "38.00",
                        "Pesca del día marinada al momento en limón de Chulucanas, ají limo y culantro, con cebolla "
                                + "morada crujiente, choclo desgranado y camote glaseado. Fresco, cítrico y con el "
                                + "punto justo de picor que define al cebiche limeño.",
                        List.of("Pescado blanco", "Limón", "Ají limo", "Cebolla morada", "Choclo", "Camote",
                                "Culantro"),
                        EnumSet.of(Allergen.FISH), 320, 420, false, "ceviche"),
                dish("Lomo saltado", "Fondos", "45.00",
                        "Tiras de lomo fino salteadas al wok con cebolla, tomate y ají amarillo, flambeadas con "
                                + "sillao y vinagre. Se acompaña de papas amarillas fritas y arroz graneado: el "
                                + "encuentro perfecto entre la cocina criolla y la chifa.",
                        List.of("Lomo de res", "Cebolla", "Tomate", "Ají amarillo", "Sillao", "Papas fritas",
                                "Arroz"),
                        EnumSet.of(Allergen.SOY, Allergen.GLUTEN), 750, 900, false, "lomo-saltado"),
                dish("Ají de gallina", "Criollos", "34.00",
                        "Gallina deshilachada en una crema sedosa de ají amarillo, pan remojado y pecanas, "
                                + "terminada con queso parmesano. Servida con arroz blanco, papa amarilla, huevo "
                                + "duro y aceituna de botija.",
                        List.of("Gallina", "Ají amarillo", "Pan", "Leche evaporada", "Pecanas", "Queso parmesano",
                                "Huevo", "Aceituna"),
                        EnumSet.of(Allergen.GLUTEN, Allergen.MILK, Allergen.TREE_NUTS, Allergen.EGGS), 680, 820,
                        false, "aji-de-gallina"),
                dish("Causa limeña", "Entradas", "26.00",
                        "Suave masa de papa amarilla prensada con ají amarillo y limón, rellena de palta y "
                                + "verduras, coronada con mayonesa de la casa. Fría, cremosa y llena de color.",
                        List.of("Papa amarilla", "Ají amarillo", "Limón", "Palta", "Mayonesa"),
                        EnumSet.of(Allergen.EGGS), 380, 460, true, "causa"),
                dish("Hamburguesa de la casa", "Hamburguesas", "32.00",
                        "Carne de res de 180 g a la parrilla en pan brioche, con queso cheddar fundido, lechuga, "
                                + "tomate y salsa de ají. Acompañada de papas fritas crocantes.",
                        List.of("Carne de res", "Pan brioche", "Queso cheddar", "Lechuga", "Tomate",
                                "Papas fritas"),
                        EnumSet.of(Allergen.GLUTEN, Allergen.MILK, Allergen.EGGS, Allergen.SESAME), 850, 1050,
                        false, "hamburguesa"),
                dish("Ensalada andina", "Ensaladas", "24.00",
                        "Quinua blanca, hojas verdes, tomates cherry, palta y queso fresco con vinagreta de "
                                + "maracuyá. Ligera, nutritiva y llena de sabores de nuestros Andes.",
                        List.of("Quinua", "Lechugas", "Tomate cherry", "Palta", "Queso fresco", "Maracuyá"),
                        EnumSet.of(Allergen.MILK), 300, 380, true, "ensalada"),
                dish("Suspiro a la limeña", "Postres", "16.00",
                        "Manjar blanco de cocción lenta coronado con merengue al oporto y un toque de canela. "
                                + "El dulce más clásico de Lima.",
                        List.of("Leche", "Yemas", "Azúcar", "Oporto", "Canela"),
                        EnumSet.of(Allergen.MILK, Allergen.EGGS, Allergen.SULPHITES), 420, 520, true, "postre"),
                dish("Chicha morada", "Bebidas", "9.00",
                        "Refresco tradicional de maíz morado hervido con piña, canela y clavo, endulzado y con "
                                + "un toque de limón. Servida bien fría.",
                        List.of("Maíz morado", "Piña", "Canela", "Clavo de olor", "Limón"),
                        EnumSet.noneOf(Allergen.class), 120, 160, true, "bebida"));
    }

    private static DishDetails dish(String name, String category, String price, String description,
            List<String> ingredients, Set<Allergen> allergens, int calMin, int calMax, boolean vegetarian,
            String modelId) {
        return new DishDetails(name, description, category, new BigDecimal(price), ingredients, allergens,
                allergens.isEmpty(), "Preparado en una cocina que manipula mariscos, gluten, lácteos y frutos secos.",
                calMin, calMax, vegetarian, false, null, modelId);
    }
}
