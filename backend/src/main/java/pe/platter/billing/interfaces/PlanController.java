package pe.platter.billing.interfaces;

import java.util.Arrays;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.billing.domain.Plan;

@RestController
@RequestMapping("/api/v1/plans")
class PlanController {

    @GetMapping
    List<PlanResource> plans() {
        return Arrays.stream(Plan.values()).map(PlanResource::from).toList();
    }
}
