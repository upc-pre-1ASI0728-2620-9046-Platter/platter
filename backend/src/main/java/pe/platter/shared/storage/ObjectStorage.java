package pe.platter.shared.storage;

import java.util.Optional;

/**
 * Puerto de almacenamiento de objetos binarios (fotos, modelos). En v1 se implementa sobre disco local;
 * el adaptador S3/Cloud Storage del diseño (CON-04) puede sustituirlo sin tocar el dominio.
 */
public interface ObjectStorage {

    void put(String key, byte[] content);

    Optional<byte[]> get(String key);
}
