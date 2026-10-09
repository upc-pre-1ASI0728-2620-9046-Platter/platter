package pe.platter.iam.application;

import java.util.Locale;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.iam.domain.UserAccount;
import pe.platter.iam.infrastructure.UserAccountRepository;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.restaurants.domain.Restaurant;
import pe.platter.shared.api.PlatterException;
import pe.platter.shared.security.JwtService;

@Service
public class AuthService {

    private final UserAccountRepository users;
    private final RestaurantService restaurants;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwt;

    AuthService(UserAccountRepository users, RestaurantService restaurants, PasswordEncoder passwordEncoder,
            JwtService jwt) {
        this.users = users;
        this.restaurants = restaurants;
        this.passwordEncoder = passwordEncoder;
        this.jwt = jwt;
    }

    @Transactional
    public Session register(String ownerName, String email, String password, String restaurantName, String address) {
        String normalized = normalize(email);
        if (users.existsByEmailIgnoreCase(normalized)) {
            throw new PlatterException(HttpStatus.CONFLICT, "EMAIL_TAKEN", "Ya existe una cuenta con ese correo");
        }
        Restaurant restaurant = restaurants.register(restaurantName.trim(), address);
        UserAccount user = users.save(new UserAccount(restaurant.getId(), ownerName.trim(), normalized,
                passwordEncoder.encode(password)));
        return session(user);
    }

    @Transactional(readOnly = true)
    public Session login(String email, String password) {
        UserAccount user = users.findByEmailIgnoreCase(normalize(email))
                .filter(u -> passwordEncoder.matches(password, u.getPasswordHash()))
                .orElseThrow(() -> new PlatterException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS",
                        "Correo o contraseña incorrectos"));
        return session(user);
    }

    @Transactional(readOnly = true)
    public UserAccount user(UUID userId) {
        return users.findById(userId).orElseThrow(() -> PlatterException.notFound("Usuario"));
    }

    private Session session(UserAccount user) {
        return new Session(user, jwt.issue(user.getId(), user.getRestaurantId()));
    }

    private static String normalize(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    public record Session(UserAccount user, JwtService.IssuedToken token) {
    }
}
