package pe.platter.assets.interfaces;

import java.time.Duration;
import java.util.List;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.shared.api.PlatterException;

/** US22: despacho de activos 3D con caché inmutable y validación condicional (ETag / If-None-Match). */
@RestController
@RequestMapping("/api/v1")
class AssetController {

    static final MediaType GLTF_BINARY = MediaType.parseMediaType("model/gltf-binary");
    private static final CacheControl IMMUTABLE = CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable();

    private final ModelLibrary library;

    AssetController(ModelLibrary library) {
        this.library = library;
    }

    @GetMapping("/models")
    List<ModelResource> models() {
        return library.all().stream().map(ModelResource::from).toList();
    }

    @GetMapping("/assets/models/{id}.glb")
    ResponseEntity<byte[]> glb(@PathVariable String id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        ModelLibrary.Asset asset = library.asset(id).orElseThrow(() -> PlatterException.notFound("Modelo 3D"));
        if (ifNoneMatch != null && ifNoneMatch.contains(asset.etag())) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(asset.etag()).cacheControl(IMMUTABLE).build();
        }
        return ResponseEntity.ok()
                .eTag(asset.etag())
                .cacheControl(IMMUTABLE)
                .contentType(GLTF_BINARY)
                .body(asset.bytes());
    }
}
