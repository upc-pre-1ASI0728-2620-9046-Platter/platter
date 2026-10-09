package pe.platter.catalog.application;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.catalog.domain.Photo;
import pe.platter.catalog.infrastructure.PhotoRepository;
import pe.platter.shared.api.PlatterException;
import pe.platter.shared.storage.ObjectStorage;

/** US05: carga de fotografías JPEG/PNG de hasta 10 MB. El formato se valida por su firma binaria. */
@Service
public class PhotoService {

    static final long MAX_BYTES = 10L * 1024 * 1024;

    private final PhotoRepository photos;
    private final ObjectStorage storage;

    PhotoService(PhotoRepository photos, ObjectStorage storage) {
        this.photos = photos;
        this.storage = storage;
    }

    @Transactional
    public Photo upload(UUID restaurantId, byte[] content) {
        if (content == null || content.length == 0) {
            throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Adjunta una fotografía");
        }
        if (content.length > MAX_BYTES) {
            throw new PlatterException(HttpStatus.CONTENT_TOO_LARGE, "IMAGE_TOO_LARGE",
                    "La imagen supera el máximo de 10 MB");
        }
        String contentType = detectType(content);
        Photo photo = new Photo(restaurantId, contentType, content.length);
        storage.put(photo.getStorageKey(), content);
        return photos.save(photo);
    }

    @Transactional(readOnly = true)
    public Photo get(UUID restaurantId, UUID photoId) {
        return photos.findByIdAndRestaurantId(photoId, restaurantId)
                .orElseThrow(() -> PlatterException.notFound("Fotografía"));
    }

    @Transactional(readOnly = true)
    public StoredPhoto read(UUID photoId) {
        Photo photo = photos.findById(photoId).orElseThrow(() -> PlatterException.notFound("Fotografía"));
        byte[] bytes = storage.get(photo.getStorageKey()).orElseThrow(() -> PlatterException.notFound("Fotografía"));
        return new StoredPhoto(photo, bytes);
    }

    static String detectType(byte[] b) {
        if (b.length > 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (b.length > 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') {
            return "image/png";
        }
        throw new PlatterException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "UNSUPPORTED_IMAGE",
                "Formato no soportado: usa una foto JPEG o PNG");
    }

    public record StoredPhoto(Photo photo, byte[] bytes) {
    }
}
