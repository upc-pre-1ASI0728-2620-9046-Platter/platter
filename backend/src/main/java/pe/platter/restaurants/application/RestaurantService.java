package pe.platter.restaurants.application;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.billing.application.PlanPolicy;
import pe.platter.billing.domain.Plan;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.restaurants.infrastructure.DiningTableRepository;
import pe.platter.restaurants.infrastructure.RestaurantRepository;
import pe.platter.shared.api.PlatterException;

@Service
public class RestaurantService {

    private final RestaurantRepository restaurants;
    private final DiningTableRepository tables;
    private final CatalogStats catalogStats;
    private final PlanPolicy planPolicy;

    RestaurantService(RestaurantRepository restaurants, DiningTableRepository tables, CatalogStats catalogStats,
            PlanPolicy planPolicy) {
        this.restaurants = restaurants;
        this.tables = tables;
        this.catalogStats = catalogStats;
        this.planPolicy = planPolicy;
    }

    @Transactional
    public Restaurant register(String name, String address) {
        return restaurants.save(new Restaurant(name, address, Plan.EMPRENDEDOR));
    }

    @Transactional(readOnly = true)
    public Restaurant get(UUID restaurantId) {
        return restaurants.findById(restaurantId).orElseThrow(() -> PlatterException.notFound("Restaurante"));
    }

    @Transactional
    public Restaurant updateProfile(UUID restaurantId, String name, String address) {
        Restaurant restaurant = get(restaurantId);
        restaurant.updateProfile(name, address);
        return restaurant;
    }

    @Transactional
    public Restaurant changePlan(UUID restaurantId, Plan plan) {
        Restaurant restaurant = get(restaurantId);
        // No se permite bajar a un plan cuyos límites ya se exceden.
        planPolicy.ensureTablesAllowed(plan, tables.countByRestaurantId(restaurantId));
        planPolicy.ensureDishesAllowed(plan, catalogStats.countDishes(restaurantId));
        restaurant.changePlan(plan);
        return restaurant;
    }

    @Transactional(readOnly = true)
    public Usage usage(UUID restaurantId) {
        return new Usage(tables.countByRestaurantId(restaurantId), catalogStats.countDishes(restaurantId));
    }

    public record Usage(long tableCount, long dishCount) {
    }
}
