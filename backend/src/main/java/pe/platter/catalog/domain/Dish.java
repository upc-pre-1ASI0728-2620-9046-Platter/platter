package pe.platter.catalog.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;

/** Agregado Dish: preparación culinaria con ficha técnica, alérgenos, foto y modelo 3D. */
@Entity
@Table(name = "dishes")
public class Dish {

    @Id
    private UUID id;

    @Column(name = "restaurant_id", nullable = false)
    private UUID restaurantId;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(nullable = false)
    private String category;

    private BigDecimal price;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "dish_ingredients", joinColumns = @JoinColumn(name = "dish_id"))
    @OrderColumn(name = "position")
    @Column(name = "ingredient")
    private List<String> ingredients = new ArrayList<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "dish_allergens", joinColumns = @JoinColumn(name = "dish_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "allergen")
    private Set<Allergen> allergens = EnumSet.noneOf(Allergen.class);

    @Column(name = "allergen_free", nullable = false)
    private boolean allergenFree;

    @Column(name = "kitchen_notes")
    private String kitchenNotes;

    @Column(name = "calories_min")
    private Integer caloriesMin;

    @Column(name = "calories_max")
    private Integer caloriesMax;

    @Column(nullable = false)
    private boolean vegetarian;

    @Column(nullable = false)
    private boolean vegan;

    @Column(name = "photo_id")
    private UUID photoId;

    @Column(name = "model_id")
    private String modelId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DishStatus status;

    @Column(nullable = false)
    private boolean available;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Dish() {
    }

    public Dish(UUID restaurantId, DishDetails details) {
        this.id = UUID.randomUUID();
        this.restaurantId = restaurantId;
        this.status = DishStatus.DRAFT;
        this.available = true;
        this.createdAt = Instant.now();
        apply(details);
    }

    public void apply(DishDetails d) {
        this.name = d.name().trim();
        this.description = d.description();
        this.category = d.category().trim();
        this.price = d.price();
        this.ingredients.clear();
        this.ingredients.addAll(d.ingredients());
        this.allergens.clear();
        this.allergens.addAll(d.allergens());
        // Un plato con alérgenos declarados no puede estar a la vez certificado como libre de alérgenos.
        this.allergenFree = d.allergenFree() && d.allergens().isEmpty();
        this.kitchenNotes = d.kitchenNotes();
        this.caloriesMin = d.caloriesMin();
        this.caloriesMax = d.caloriesMax();
        this.vegan = d.vegan();
        this.vegetarian = d.vegetarian() || d.vegan();
        this.photoId = d.photoId();
        this.modelId = d.modelId();
        touch();
    }

    /** Reglas de negocio del Canvas de Catálogo: devuelve los motivos por los que no se puede publicar. */
    public Map<String, String> publicationIssues() {
        Map<String, String> issues = new LinkedHashMap<>();
        if (name == null || name.isBlank()) {
            issues.put("name", "El plato necesita un nombre");
        }
        if (category == null || category.isBlank()) {
            issues.put("category", "Asigna una categoría");
        }
        if (price == null || price.signum() <= 0) {
            issues.put("priceSoles", "Asigna un precio mayor a cero");
        }
        if (photoId == null) {
            issues.put("photoId", "Agrega una fotografía de referencia");
        }
        if (modelId == null) {
            issues.put("modelId", "Vincula un modelo 3D de la biblioteca");
        }
        if (allergens.isEmpty() && !allergenFree) {
            issues.put("allergens", "Declara los alérgenos o marca el plato como libre de alérgenos");
        }
        return issues;
    }

    public void publish() {
        this.status = DishStatus.PUBLISHED;
        touch();
    }

    public void changeAvailability(boolean available) {
        this.available = available;
        touch();
    }

    private void touch() {
        this.updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getRestaurantId() {
        return restaurantId;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public String getCategory() {
        return category;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public List<String> getIngredients() {
        return List.copyOf(ingredients);
    }

    public Set<Allergen> getAllergens() {
        return allergens.isEmpty() ? EnumSet.noneOf(Allergen.class) : EnumSet.copyOf(allergens);
    }

    public boolean isAllergenFree() {
        return allergenFree;
    }

    public String getKitchenNotes() {
        return kitchenNotes;
    }

    public Integer getCaloriesMin() {
        return caloriesMin;
    }

    public Integer getCaloriesMax() {
        return caloriesMax;
    }

    public boolean isVegetarian() {
        return vegetarian;
    }

    public boolean isVegan() {
        return vegan;
    }

    public UUID getPhotoId() {
        return photoId;
    }

    public String getModelId() {
        return modelId;
    }

    public DishStatus getStatus() {
        return status;
    }

    public boolean isAvailable() {
        return available;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
