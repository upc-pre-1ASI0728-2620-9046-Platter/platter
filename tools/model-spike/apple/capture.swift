// Fotogrametría con Apple Object Capture (RealityKit · PhotogrammetrySession), gratis en Mac con Apple Silicon.
//
//   capture <carpeta-de-fotos> <carpeta-de-salida> [preview|reduced|medium|full]
//
// Escribe en la carpeta de salida:
//   model.usdz   modelo listo para Quick Look (iPhone)
//   obj/         el mismo modelo en OBJ + MTL + texturas (se convierte a GLB después)
// Imprime "PROGRESS <0..1>" para que el script de Node muestre el avance.
import Foundation
import RealityKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ERROR \(message)\n".utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("Uso: capture <carpeta-de-fotos> <carpeta-de-salida> [preview|reduced|medium|full]")
}
guard PhotogrammetrySession.isSupported else {
    fail("Este equipo no soporta Object Capture (requiere Mac con Apple Silicon o GPU compatible)")
}

let input = URL(fileURLWithPath: args[1], isDirectory: true)
let output = URL(fileURLWithPath: args[2], isDirectory: true)
let detail: PhotogrammetrySession.Request.Detail = switch args.count > 3 ? args[3] : "reduced" {
case "preview": .preview
case "medium": .medium
case "full": .full
default: .reduced
}

let objDir = output.appendingPathComponent("obj", isDirectory: true)
do {
    try FileManager.default.createDirectory(at: objDir, withIntermediateDirectories: true)
} catch {
    fail("No se pudo crear \(objDir.path): \(error.localizedDescription)")
}

var config = PhotogrammetrySession.Configuration()
config.sampleOrdering = .unordered
config.featureSensitivity = .normal
config.isObjectMaskingEnabled = true // aísla el plato del fondo

let session: PhotogrammetrySession
do {
    session = try PhotogrammetrySession(input: input, configuration: config)
} catch {
    fail("No se pudieron leer las fotos de \(input.path): \(error.localizedDescription)")
}

let usdz = PhotogrammetrySession.Request.modelFile(url: output.appendingPathComponent("model.usdz"), detail: detail)
// Con una carpeta como destino, Object Capture escribe OBJ + MTL + texturas.
let obj = PhotogrammetrySession.Request.modelFile(url: objDir, detail: detail)

let watcher = Task {
    var failures = 0
    do {
        for try await event in session.outputs {
            switch event {
            case .requestProgress(_, let fraction):
                print(String(format: "PROGRESS %.3f", fraction))
            case .requestComplete(_, .modelFile(let url)):
                print("WROTE \(url.path)")
            case .requestComplete:
                break
            case .requestError(_, let error):
                failures += 1
                FileHandle.standardError.write(Data("ERROR \(error.localizedDescription)\n".utf8))
            case .invalidSample(let id, let reason):
                print("WARN foto \(id) descartada: \(reason)")
            case .skippedSample(let id):
                print("WARN foto \(id) omitida")
            case .automaticDownsampling:
                print("WARN poca memoria: las fotos se reducen automáticamente")
            case .stitchingIncomplete:
                print("WARN no se pudieron unir todas las fotos: faltan ángulos o superposición")
            case .processingComplete:
                exit(failures == 0 ? 0 : 1)
            case .processingCancelled:
                fail("Procesamiento cancelado")
            default:
                break
            }
        }
    } catch {
        fail("Object Capture falló: \(error.localizedDescription)")
    }
}

do {
    try session.process(requests: [usdz, obj])
} catch {
    fail("No se pudo iniciar el procesamiento: \(error.localizedDescription)")
}
_ = watcher
RunLoop.main.run()
