package pe.platter.restaurants.infrastructure;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.platter.restaurants.domain.DiningTable;

public interface DiningTableRepository extends JpaRepository<DiningTable, UUID> {

    List<DiningTable> findByRestaurantIdOrderByCreatedAtAscLabelAsc(UUID restaurantId);

    Optional<DiningTable> findByIdAndRestaurantId(UUID id, UUID restaurantId);

    Optional<DiningTable> findByToken(String token);

    boolean existsByRestaurantIdAndLabelIgnoreCase(UUID restaurantId, String label);

    long countByRestaurantId(UUID restaurantId);
}
