package pe.platter.catalog.interfaces;

import java.util.Arrays;
import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.catalog.domain.Allergen;

@RestController
@RequestMapping("/api/v1")
class CatalogReferenceController {

    static final List<String> CATEGORIES = List.of("Entradas", "Ceviches", "Fondos", "Criollos", "Sánguches",
            "Hamburguesas", "Pizzas", "Ensaladas", "Postres", "Bebidas");

    @GetMapping("/allergens")
    List<AllergenResource> allergens() {
        return Arrays.stream(Allergen.values()).map(a -> new AllergenResource(a.name(), a.label(), a.icon())).toList();
    }

    @GetMapping("/categories")
    List<String> categories() {
        return CATEGORIES;
    }

    record AllergenResource(String code, String label, String icon) {
    }
}
