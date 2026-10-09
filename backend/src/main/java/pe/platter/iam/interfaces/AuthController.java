package pe.platter.iam.interfaces;

import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.iam.application.AuthService;
import pe.platter.iam.domain.UserAccount;
import pe.platter.restaurants.interfaces.RestaurantResourceAssembler;
import pe.platter.restaurants.interfaces.RestaurantResourceAssembler.RestaurantResource;
import pe.platter.shared.security.CurrentOwner;

@RestController
@RequestMapping("/api/v1")
class AuthController {

    private final AuthService auth;
    private final RestaurantResourceAssembler restaurants;

    AuthController(AuthService auth, RestaurantResourceAssembler restaurants) {
        this.auth = auth;
        this.restaurants = restaurants;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return toResponse(auth.register(request.ownerName(), request.email(), request.password(),
                request.restaurantName(), request.address()));
    }

    @PostMapping("/auth/login")
    AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return toResponse(auth.login(request.email(), request.password()));
    }

    @GetMapping("/me")
    MeResponse me(CurrentOwner owner) {
        return new MeResponse(UserResource.from(auth.user(owner.userId())),
                restaurants.toResource(owner.restaurantId()));
    }

    private AuthResponse toResponse(AuthService.Session session) {
        return new AuthResponse(session.token().token(), session.token().expiresIn(),
                UserResource.from(session.user()), restaurants.toResource(session.user().getRestaurantId()));
    }

    record RegisterRequest(
            @NotBlank @Size(max = 120) String ownerName,
            @NotBlank @Email @Size(max = 180) String email,
            @NotBlank @Size(min = 8, max = 100, message = "Debe tener al menos 8 caracteres") String password,
            @NotBlank @Size(max = 120) String restaurantName,
            @Size(max = 255) String address) {
    }

    record LoginRequest(@NotBlank @Email String email, @NotBlank String password) {
    }

    record UserResource(UUID id, String name, String email) {
        static UserResource from(UserAccount user) {
            return new UserResource(user.getId(), user.getName(), user.getEmail());
        }
    }

    record AuthResponse(String token, long expiresIn, UserResource user, RestaurantResource restaurant) {
    }

    record MeResponse(UserResource user, RestaurantResource restaurant) {
    }
}
