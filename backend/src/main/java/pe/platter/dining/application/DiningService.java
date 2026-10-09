package pe.platter.dining.application;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.catalog.application.MenuCatalogQuery;
import pe.platter.catalog.application.MenuCatalogQuery.CategoryView;
import pe.platter.catalog.application.MenuCatalogQuery.MenuCatalogView;
import pe.platter.dining.domain.InteractionEvent;
import pe.platter.dining.domain.InteractionType;
import pe.platter.dining.infrastructure.InteractionEventRepository;
import pe.platter.restaurants.application.TableResolver;
import pe.platter.restaurants.application.TableResolver.ValidatedTableContext;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.shared.api.PlatterException;

/** AR Dining Experience: sesión anónima contextualizada por el token de la mesa. */
@Service
public class DiningService {

    private final TableResolver tables;
    private final MenuCatalogQuery menus;
    private final InteractionEventRepository events;

    DiningService(TableResolver tables, MenuCatalogQuery menus, InteractionEventRepository events) {
        this.tables = tables;
        this.menus = menus;
        this.events = events;
    }

    public Optional<ValidatedTableContext> initializeSession(String tableToken) {
        return tables.resolve(tableToken);
    }

    /** Los filtros de alérgenos tienen precedencia absoluta: se omite todo plato que contenga uno excluido. */
    public FilteredMenu menu(UUID restaurantId, Set<String> excludedAllergens) {
        Restaurant restaurant = tables.restaurant(restaurantId)
                .orElseThrow(() -> PlatterException.notFound("Restaurante"));
        MenuCatalogView menu = menus.activeMenu(restaurantId);
        List<CategoryView> categories = menu.categories().stream()
                .map(c -> new CategoryView(c.name(), c.dishes().stream()
                        .filter(d -> d.allergens().stream().noneMatch(excludedAllergens::contains))
                        .toList()))
                .filter(c -> !c.dishes().isEmpty())
                .toList();
        return new FilteredMenu(restaurant.getId(), restaurant.getName(), categories);
    }

    @Transactional
    public void log(InteractionType type, String tableToken, UUID dishId, Integer durationSeconds) {
        UUID restaurantId = null;
        UUID tableId = null;
        if (tableToken != null) {
            Optional<ValidatedTableContext> table = tables.resolve(tableToken);
            if (table.isEmpty()) {
                return;
            }
            restaurantId = table.get().restaurantId();
            tableId = table.get().tableId();
        }
        if (restaurantId == null && dishId != null) {
            restaurantId = menus.restaurantOfPublishedDish(dishId).orElse(null);
        }
        if (restaurantId == null) {
            return;
        }
        if (dishId != null && !belongsTo(restaurantId, dishId)) {
            dishId = null;
        }
        events.save(new InteractionEvent(restaurantId, tableId, dishId, type, durationSeconds));
    }

    private boolean belongsTo(UUID restaurantId, UUID dishId) {
        return menus.activeMenu(restaurantId).categories().stream()
                .flatMap(c -> c.dishes().stream())
                .anyMatch(d -> d.id().equals(dishId));
    }

    public record FilteredMenu(UUID restaurantId, String restaurantName, List<CategoryView> categories) {
    }
}
