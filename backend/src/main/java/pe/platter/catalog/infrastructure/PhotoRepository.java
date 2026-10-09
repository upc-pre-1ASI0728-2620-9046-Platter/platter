package pe.platter.catalog.infrastructure;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.platter.catalog.domain.Photo;

public interface PhotoRepository extends JpaRepository<Photo, UUID> {

    Optional<Photo> findByIdAndRestaurantId(UUID id, UUID restaurantId);
}
