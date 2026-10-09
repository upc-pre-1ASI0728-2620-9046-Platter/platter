package pe.platter.restaurants.infrastructure;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import pe.platter.restaurants.domain.Restaurant;

public interface RestaurantRepository extends JpaRepository<Restaurant, UUID> {
}
