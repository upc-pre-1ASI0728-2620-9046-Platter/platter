package pe.platter.restaurants.interfaces;

import java.util.UUID;

import org.springframework.stereotype.Component;

import pe.platter.billing.interfaces.PlanResource;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.restaurants.domain.Restaurant;

@Component
public class RestaurantResourceAssembler {

    private final RestaurantService restaurants;

    RestaurantResourceAssembler(RestaurantService restaurants) {
        this.restaurants = restaurants;
    }

    public RestaurantResource toResource(UUID restaurantId) {
        Restaurant restaurant = restaurants.get(restaurantId);
        RestaurantService.Usage usage = restaurants.usage(restaurantId);
        return new RestaurantResource(restaurant.getId(), restaurant.getName(), restaurant.getAddress(),
                PlanResource.from(restaurant.getPlan()), usage.tableCount(), usage.dishCount());
    }

    public record RestaurantResource(UUID id, String name, String address, PlanResource plan, long tableCount,
            long dishCount) {
    }
}
