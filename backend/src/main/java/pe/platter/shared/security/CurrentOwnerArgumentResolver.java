package pe.platter.shared.security;

import java.util.UUID;

import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import pe.platter.shared.api.PlatterException;

class CurrentOwnerArgumentResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.getParameterType() == CurrentOwner.class;
    }

    @Override
    public CurrentOwner resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
            NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Jwt jwt) {
            return new CurrentOwner(UUID.fromString(jwt.getSubject()),
                    UUID.fromString(jwt.getClaimAsString(JwtService.RESTAURANT_CLAIM)));
        }
        throw new PlatterException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Inicia sesión para continuar");
    }
}
