package pe.platter.shared.security;

import java.time.Instant;
import java.util.UUID;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import pe.platter.shared.config.PlatterProperties;

@Service
public class JwtService {

    static final String RESTAURANT_CLAIM = "rid";

    private final JwtEncoder encoder;
    private final PlatterProperties properties;

    public JwtService(JwtEncoder encoder, PlatterProperties properties) {
        this.encoder = encoder;
        this.properties = properties;
    }

    public IssuedToken issue(UUID userId, UUID restaurantId) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("platter")
                .subject(userId.toString())
                .claim(RESTAURANT_CLAIM, restaurantId.toString())
                .issuedAt(now)
                .expiresAt(now.plus(properties.jwt().ttl()))
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new IssuedToken(token, properties.jwt().ttl().toSeconds());
    }

    public record IssuedToken(String token, long expiresIn) {
    }
}
