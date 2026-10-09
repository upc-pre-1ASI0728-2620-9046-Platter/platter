package pe.platter.restaurants.interfaces;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.billing.domain.Plan;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.restaurants.interfaces.RestaurantResourceAssembler.RestaurantResource;
import pe.platter.shared.security.CurrentOwner;

@RestController
@RequestMapping("/api/v1/restaurant")
class RestaurantController {

    private final RestaurantService restaurants;
    private final RestaurantResourceAssembler assembler;

    RestaurantController(RestaurantService restaurants, RestaurantResourceAssembler assembler) {
        this.restaurants = restaurants;
        this.assembler = assembler;
    }

    @GetMapping
    RestaurantResource get(CurrentOwner owner) {
        return assembler.toResource(owner.restaurantId());
    }

    @PutMapping
    RestaurantResource update(CurrentOwner owner, @Valid @RequestBody UpdateRestaurantRequest request) {
        restaurants.updateProfile(owner.restaurantId(), request.name().trim(), request.address());
        return assembler.toResource(owner.restaurantId());
    }

    @PutMapping("/plan")
    RestaurantResource changePlan(CurrentOwner owner, @Valid @RequestBody ChangePlanRequest request) {
        restaurants.changePlan(owner.restaurantId(), request.planCode());
        return assembler.toResource(owner.restaurantId());
    }

    record UpdateRestaurantRequest(@NotBlank @Size(max = 120) String name, @Size(max = 255) String address) {
    }

    record ChangePlanRequest(@NotNull Plan planCode) {
    }
}
