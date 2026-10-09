package pe.platter.restaurants.application;

import java.util.UUID;

/** Puerto hacia el contexto de Catálogo para mostrar el uso del plan sin acoplarse a sus entidades. */
public interface CatalogStats {

    long countDishes(UUID restaurantId);
}
