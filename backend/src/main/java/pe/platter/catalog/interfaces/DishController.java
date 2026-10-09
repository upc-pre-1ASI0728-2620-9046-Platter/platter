package pe.platter.catalog.interfaces;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import pe.platter.analysis.domain.GastronomicInference;
import pe.platter.catalog.application.DishAnalysisService;
import pe.platter.catalog.application.DishService;
import pe.platter.catalog.application.PhotoService;
import pe.platter.catalog.domain.Allergen;
import pe.platter.catalog.domain.DishDetails;
import pe.platter.catalog.domain.Photo;
import pe.platter.catalog.interfaces.DishResources.Calories;
import pe.platter.catalog.interfaces.DishResources.DishResource;
import pe.platter.shared.api.PlatterException;
import pe.platter.shared.security.CurrentOwner;

@RestController
@RequestMapping("/api/v1/dishes")
class DishController {

    private final DishService dishes;
    private final PhotoService photos;
    private final DishAnalysisService analysis;
    private final DishResources resources;

    DishController(DishService dishes, PhotoService photos, DishAnalysisService analysis, DishResources resources) {
        this.dishes = dishes;
        this.photos = photos;
        this.analysis = analysis;
        this.resources = resources;
    }

    @PostMapping(value = "/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    PhotoResource uploadPhoto(CurrentOwner owner, @RequestPart("image") MultipartFile image) {
        Photo photo = photos.upload(owner.restaurantId(), bytes(image));
        return new PhotoResource(photo.getId(), DishResources.photoUrl(photo.getId()));
    }

    /** US06/US07/US08/US21: análisis multimodal de la foto (archivo nuevo o una foto ya subida). */
    @PostMapping(value = "/analyze", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    AnalysisResource analyze(CurrentOwner owner, @RequestPart(value = "image", required = false) MultipartFile image,
            @RequestParam(value = "photoId", required = false) UUID photoId) {
        UUID id = photoId;
        if (image != null && !image.isEmpty()) {
            id = photos.upload(owner.restaurantId(), bytes(image)).getId();
        }
        if (id == null) {
            throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Adjunta una fotografía",
                    Map.of("image", "Envía 'image' o 'photoId'"));
        }
        DishAnalysisService.Result result = analysis.analyze(owner.restaurantId(), id);
        GastronomicInference i = result.inference();
        return new AnalysisResource(result.photo().getId(), DishResources.photoUrl(result.photo().getId()),
                i.suggestedName(), i.description(), i.category(), i.ingredients(), i.allergenCodes(),
                DishResources.calories(i.caloriesMin(), i.caloriesMax()), i.confidence(), result.lowConfidence(),
                result.suggestedModelId());
    }

    @GetMapping
    List<DishResource> list(CurrentOwner owner) {
        return dishes.list(owner.restaurantId()).stream().map(resources::toResource).toList();
    }

    @GetMapping("/{id}")
    DishResource get(CurrentOwner owner, @PathVariable UUID id) {
        return resources.toResource(dishes.get(owner.restaurantId(), id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    DishResource create(CurrentOwner owner, @Valid @RequestBody DishInput input) {
        return resources.toResource(dishes.create(owner.restaurantId(), input.toDetails()));
    }

    @PutMapping("/{id}")
    DishResource update(CurrentOwner owner, @PathVariable UUID id, @Valid @RequestBody DishInput input) {
        return resources.toResource(dishes.update(owner.restaurantId(), id, input.toDetails()));
    }

    @PostMapping("/{id}/publish")
    DishResource publish(CurrentOwner owner, @PathVariable UUID id) {
        return resources.toResource(dishes.publish(owner.restaurantId(), id));
    }

    @PatchMapping("/{id}/availability")
    DishResource availability(CurrentOwner owner, @PathVariable UUID id,
            @Valid @RequestBody AvailabilityRequest request) {
        return resources.toResource(dishes.changeAvailability(owner.restaurantId(), id, request.available()));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(CurrentOwner owner, @PathVariable UUID id) {
        dishes.delete(owner.restaurantId(), id);
    }

    private static byte[] bytes(MultipartFile file) {
        try {
            return file.getBytes();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    record PhotoResource(UUID photoId, String photoUrl) {
    }

    record AnalysisResource(UUID photoId, String photoUrl, String suggestedName, String description,
            String category, List<String> ingredients, List<String> allergens, Calories estimatedCalories,
            double confidence, boolean lowConfidence, String suggestedModelId) {
    }

    record AvailabilityRequest(@NotNull Boolean available) {
    }

    record DishInput(
            @NotBlank @Size(max = 120) String name,
            @Size(max = 1000) String description,
            @NotBlank @Size(max = 60) String category,
            @DecimalMin(value = "0.00") @DecimalMax("99999.99") BigDecimal priceSoles,
            @Size(max = 30) List<@NotBlank @Size(max = 80) String> ingredients,
            @Size(max = 14) List<String> allergens,
            Boolean allergenFree,
            @Size(max = 500) String kitchenNotes,
            @Min(0) @Max(5000) Integer caloriesMin,
            @Min(0) @Max(5000) Integer caloriesMax,
            Boolean vegetarian,
            Boolean vegan,
            UUID photoId,
            @Size(max = 60) String modelId) {

        DishDetails toDetails() {
            Set<Allergen> parsed = EnumSet.noneOf(Allergen.class);
            Map<String, String> unknown = new LinkedHashMap<>();
            for (String code : allergens == null ? List.<String>of() : allergens) {
                Allergen.parse(code).ifPresentOrElse(parsed::add,
                        () -> unknown.put("allergens", "Alérgeno desconocido: " + code));
            }
            if (!unknown.isEmpty()) {
                throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Revisa los campos marcados",
                        unknown);
            }
            List<String> cleanIngredients = ingredients == null ? List.of()
                    : ingredients.stream().map(String::trim).distinct().toList();
            return new DishDetails(name, blankToNull(description), category, priceSoles, cleanIngredients, parsed,
                    Boolean.TRUE.equals(allergenFree), blankToNull(kitchenNotes), caloriesMin, caloriesMax,
                    Boolean.TRUE.equals(vegetarian), Boolean.TRUE.equals(vegan), photoId,
                    blankToNull(modelId));
        }

        private static String blankToNull(String value) {
            return value == null || value.isBlank() ? null : value.trim();
        }
    }
}
