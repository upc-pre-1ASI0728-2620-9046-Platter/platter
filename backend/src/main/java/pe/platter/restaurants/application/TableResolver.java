package pe.platter.restaurants.application;

import java.util.Optional;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.restaurants.domain.Restaurant;
import pe.platter.restaurants.infrastructure.DiningTableRepository;
import pe.platter.restaurants.infrastructure.RestaurantRepository;

/** Outbound capability {@code ResolveTableToken(token): ValidatedTableContext} consumida por la experiencia WebAR. */
@Service
public class TableResolver {

    private final DiningTableRepository tables;
    private final RestaurantRepository restaurants;

    TableResolver(DiningTableRepository tables, RestaurantRepository restaurants) {
        this.tables = tables;
        this.restaurants = restaurants;
    }

    @Transactional(readOnly = true)
    public Optional<ValidatedTableContext> resolve(String token) {
        return tables.findByToken(token).flatMap(table -> restaurants.findById(table.getRestaurantId())
                .map(r -> new ValidatedTableContext(table.getId(), table.getLabel(), table.isActive(), r.getId(),
                        r.getName())));
    }

    @Transactional(readOnly = true)
    public Optional<Restaurant> restaurant(UUID restaurantId) {
        return restaurants.findById(restaurantId);
    }

    public record ValidatedTableContext(UUID tableId, String label, boolean active, UUID restaurantId,
            String restaurantName) {
    }
}
