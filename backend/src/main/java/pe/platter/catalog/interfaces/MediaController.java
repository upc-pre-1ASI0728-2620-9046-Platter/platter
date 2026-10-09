package pe.platter.catalog.interfaces;

import java.time.Duration;
import java.util.UUID;

import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.catalog.application.PhotoService;

/** Las fotos son inmutables (cada carga genera un id nuevo), por lo que se sirven con caché pública larga. */
@RestController
class MediaController {

    private final PhotoService photos;

    MediaController(PhotoService photos) {
        this.photos = photos;
    }

    @GetMapping("/api/v1/media/photos/{id}")
    ResponseEntity<byte[]> photo(@PathVariable UUID id) {
        PhotoService.StoredPhoto stored = photos.read(id);
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable())
                .contentType(MediaType.parseMediaType(stored.photo().getContentType()))
                .body(stored.bytes());
    }
}
