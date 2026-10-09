package pe.platter.dining.interfaces;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.assets.interfaces.ModelResource;
import pe.platter.catalog.application.MenuCatalogQuery.DishView;
import pe.platter.catalog.interfaces.DishResources;
import pe.platter.catalog.interfaces.DishResources.Calories;
import pe.platter.dining.application.DiningService;
import pe.platter.dining.domain.InteractionType;
import pe.platter.shared.api.PlatterException;

/** API pública del comensal: sin autenticación, contextualizada por el token del QR de mesa (US13–US17). */
@RestController
@RequestMapping("/api/v1/public")
class PublicDiningController {

    private final DiningService dining;
    private final DishResources resources;

    PublicDiningController(DiningService dining, DishResources resources) {
        this.dining = dining;
        this.resources = resources;
    }

    @GetMapping("/tables/{token}")
    TableSession table(@PathVariable String token) {
        return dining.initializeSession(token)
                .map(t -> new TableSession(new TableInfo(t.label(), t.active()),
                        new RestaurantInfo(t.restaurantId(), t.restaurantName())))
                .orElseThrow(() -> new PlatterException(HttpStatus.NOT_FOUND, "TABLE_NOT_FOUND",
                        "Este código QR no corresponde a ninguna mesa activa"));
    }

    @GetMapping("/restaurants/{restaurantId}/menu")
    PublicMenu menu(@PathVariable UUID restaurantId, @RequestParam(required = false) String exclude) {
        Set<String> excluded = exclude == null ? Set.of()
                : Arrays.stream(exclude.split(",")).map(s -> s.trim().toUpperCase(Locale.ROOT))
                        .filter(s -> !s.isEmpty()).collect(Collectors.toCollection(java.util.TreeSet::new));
        DiningService.FilteredMenu menu = dining.menu(restaurantId, excluded);
        return new PublicMenu(new RestaurantInfo(menu.restaurantId(), menu.restaurantName()), List.copyOf(excluded),
                menu.categories().stream()
                        .map(c -> new PublicCategory(c.name(), c.dishes().stream().map(this::toPublic).toList()))
                        .toList());
    }

    @PostMapping("/events")
    @ResponseStatus(HttpStatus.ACCEPTED)
    void event(@Valid @RequestBody EventRequest request) {
        dining.log(request.type(), request.tableToken(), request.dishId(), request.durationSeconds());
    }

    private PublicDish toPublic(DishView d) {
        return new PublicDish(d.id(), d.name(), d.description(), d.category(), d.price(), d.ingredients(),
                d.allergens(), d.allergenFree(), d.kitchenNotes(), DishResources.calories(d.caloriesMin(),
                        d.caloriesMax()), d.vegetarian(), d.vegan(), DishResources.photoUrl(d.photoId()),
                resources.model(d.modelId()), d.available());
    }

    record TableSession(TableInfo table, RestaurantInfo restaurant) {
    }

    record TableInfo(String label, boolean active) {
    }

    record RestaurantInfo(UUID id, String name) {
    }

    record PublicMenu(RestaurantInfo restaurant, List<String> excludedAllergens, List<PublicCategory> categories) {
    }

    record PublicCategory(String name, List<PublicDish> dishes) {
    }

    record PublicDish(UUID id, String name, String description, String category, BigDecimal priceSoles,
            List<String> ingredients, List<String> allergens, boolean allergenFree, String kitchenNotes,
            Calories calories, boolean vegetarian, boolean vegan, String photoUrl, ModelResource model,
            boolean available) {
    }

    record EventRequest(@NotNull InteractionType type, @Size(max = 64) String tableToken, UUID dishId,
            @Min(0) @Max(36000) Integer durationSeconds) {
    }
}
