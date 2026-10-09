package pe.platter.restaurants.interfaces;

import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.restaurants.application.MenuLinks;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.restaurants.application.TableService;
import pe.platter.restaurants.domain.DiningTable;
import pe.platter.restaurants.infrastructure.QrRenderer;
import pe.platter.shared.api.PlatterException;
import pe.platter.shared.security.CurrentOwner;

@RestController
@RequestMapping("/api/v1/tables")
class TableController {

    private final TableService tables;
    private final RestaurantService restaurants;
    private final QrRenderer qr;
    private final MenuLinks links;

    TableController(TableService tables, RestaurantService restaurants, QrRenderer qr, MenuLinks links) {
        this.tables = tables;
        this.restaurants = restaurants;
        this.qr = qr;
        this.links = links;
    }

    @GetMapping
    List<TableResource> list(CurrentOwner owner) {
        return tables.list(owner.restaurantId()).stream().map(this::toResource).toList();
    }

    @PostMapping("/batch")
    @ResponseStatus(HttpStatus.CREATED)
    List<TableResource> batch(CurrentOwner owner, @Valid @RequestBody BatchRequest request) {
        return tables.createRange(owner.restaurantId(), request.from(), request.to(), request.prefix()).stream()
                .map(this::toResource).toList();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    TableResource create(CurrentOwner owner, @Valid @RequestBody CreateRequest request) {
        return toResource(tables.create(owner.restaurantId(), request.label()));
    }

    @PatchMapping("/{id}")
    TableResource update(CurrentOwner owner, @PathVariable UUID id, @Valid @RequestBody UpdateRequest request) {
        return toResource(tables.setActive(owner.restaurantId(), id, request.active()));
    }

    @GetMapping(value = "/{id}/qr.png", produces = MediaType.IMAGE_PNG_VALUE)
    ResponseEntity<byte[]> qrPng(CurrentOwner owner, @PathVariable UUID id,
            @RequestParam(defaultValue = "1024") int size) {
        DiningTable table = tables.get(owner.restaurantId(), id);
        int clamped = Math.clamp(size, 128, 2048);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noCache().cachePrivate())
                .contentType(MediaType.IMAGE_PNG)
                .body(qr.png(links.menuUrl(table.getToken()), clamped));
    }

    @GetMapping(value = "/qr-sheet.pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    ResponseEntity<byte[]> qrSheet(CurrentOwner owner, @RequestParam(required = false) String ids) {
        List<DiningTable> all = tables.list(owner.restaurantId());
        if (ids != null && !ids.isBlank()) {
            Set<String> wanted = Arrays.stream(ids.split(",")).map(String::trim).collect(Collectors.toSet());
            all = all.stream().filter(t -> wanted.contains(t.getId().toString())).toList();
        }
        if (all.isEmpty()) {
            throw PlatterException.notFound("Mesas");
        }
        String name = restaurants.get(owner.restaurantId()).getName();
        byte[] pdf = qr.sheet(name, all.stream()
                .map(t -> new QrRenderer.Card(t.getLabel(), links.menuUrl(t.getToken()))).toList());
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.inline().filename("platter-qr-mesas.pdf").build().toString())
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    }

    private TableResource toResource(DiningTable t) {
        return new TableResource(t.getId(), t.getLabel(), t.getToken(), t.isActive(), links.menuUrl(t.getToken()));
    }

    record TableResource(UUID id, String label, String token, boolean active, String menuUrl) {
    }

    record BatchRequest(@NotNull @Min(1) Integer from, @NotNull @Max(999) Integer to,
            @Size(max = 40) String prefix) {
    }

    record CreateRequest(@NotBlank @Size(max = 60) String label) {
    }

    record UpdateRequest(@NotNull Boolean active) {
    }
}
