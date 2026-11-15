package pe.platter.dining.interfaces;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.dining.application.AnalyticsService;
import pe.platter.shared.security.CurrentOwner;

import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;

@Tag(name = "Analytics", description = "Resumen de interacciones de los comensales para el dueño.")
@SecurityRequirement(name = "bearerAuth")
@RestController
@RequestMapping("/api/v1/analytics")
class AnalyticsController {

    private final AnalyticsService analytics;

    AnalyticsController(AnalyticsService analytics) {
        this.analytics = analytics;
    }

    @GetMapping("/summary")
    AnalyticsService.Summary summary(CurrentOwner owner, @RequestParam(defaultValue = "7") int days) {
        return analytics.summary(owner.restaurantId(), Math.clamp(days, 1, 90));
    }
}
