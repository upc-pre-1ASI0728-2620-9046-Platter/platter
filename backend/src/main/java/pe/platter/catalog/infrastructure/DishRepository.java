package pe.platter.catalog.infrastructure;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.platter.catalog.domain.Dish;
import pe.platter.catalog.domain.DishStatus;

public interface DishRepository extends JpaRepository<Dish, UUID> {

    List<Dish> findByRestaurantIdOrderByCategoryAscNameAsc(UUID restaurantId);

    List<Dish> findByRestaurantIdAndStatusOrderByCategoryAscNameAsc(UUID restaurantId, DishStatus status);

    Optional<Dish> findByIdAndRestaurantId(UUID id, UUID restaurantId);

    long countByRestaurantId(UUID restaurantId);
}
