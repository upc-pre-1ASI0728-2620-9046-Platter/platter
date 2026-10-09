import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_exception.dart';
import '../../api/error_messages.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../utils/photo_picker.dart';
import 'dish_form_screen.dart';

const aiUnavailableMessage =
    'El análisis con IA no está disponible ahora. Puedes completar la ficha manualmente.';

enum _Step { pick, uploading, analyzing }

/// Paso 1 del alta de plato (US05–US08): foto → subida → análisis con IA.
class NewDishScreen extends StatefulWidget {
  const NewDishScreen({super.key});

  @override
  State<NewDishScreen> createState() => _NewDishScreenState();
}

class _NewDishScreenState extends State<NewDishScreen> {
  _Step _step = _Step.pick;
  PickedPhoto? _photo;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    final PickedPhoto? photo;
    try {
      photo = await pickPhoto(source);
    } on PhotoValidationException catch (e) {
      setState(() => _error = e.message);
      return;
    } catch (e) {
      setState(() => _error = 'No se pudo abrir la ${source == ImageSource.camera ? 'cámara' : 'galería'}.');
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _photo = photo);
    await _uploadAndAnalyze(photo);
  }

  Future<void> _uploadAndAnalyze(PickedPhoto photo) async {
    final session = SessionScope.read(context);
    setState(() => _step = _Step.uploading);
    final UploadedPhoto uploaded;
    try {
      uploaded = await session.api.uploadPhoto(photo.bytes, fileName: photo.fileName, contentType: photo.mimeType);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.pick;
          _error = friendlyError(e);
        });
      }
      return;
    }
    if (!mounted) return;

    final seed = DishFormSeed(photoId: uploaded.photoId, photoUrl: uploaded.photoUrl, photoBytes: photo.bytes);

    if (session.restaurant?.plan?.aiAnalysis == false) {
      await _openForm(seed.withNotice('Tu plan actual no incluye análisis con IA. Completa la ficha manualmente.'));
      return;
    }

    setState(() => _step = _Step.analyzing);
    try {
      final analysis = await session.api.analyzePhoto(uploaded.photoId);
      if (!mounted) return;
      if (analysis.lowConfidence) {
        final retake = await _askLowConfidence();
        if (!mounted) return;
        if (retake) {
          setState(() {
            _step = _Step.pick;
            _photo = null;
          });
          return;
        }
        await _openForm(seed);
        return;
      }
      await _openForm(seed.withAnalysis(analysis));
    } on ApiException catch (e) {
      if (!mounted) return;
      final String notice = switch (e.code) {
        'AI_UNAVAILABLE' => aiUnavailableMessage,
        'PLAN_LIMIT_REACHED' =>
          'Alcanzaste el límite de análisis con IA de tu plan. Completa la ficha manualmente.',
        _ when e.status == 403 => 'Tu plan actual no incluye análisis con IA. Completa la ficha manualmente.',
        _ => '${friendlyError(e)} Puedes completar la ficha manualmente.',
      };
      await _openForm(seed.withNotice(notice));
    } catch (e) {
      // Timeout o red: degradación elegante (QA-03).
      if (mounted) await _openForm(seed.withNotice(aiUnavailableMessage));
    }
  }

  Future<bool> _askLowConfidence() async {
    final retake = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.blur_on),
        title: const Text('La foto no es clara'),
        content: const Text(
          'La IA no pudo reconocer bien el plato. Puedes tomar otra foto con mejor luz '
          'y encuadre, o completar la ficha manualmente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Completar manualmente')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tomar otra')),
        ],
      ),
    );
    return retake ?? false;
  }

  Future<void> _openForm(DishFormSeed seed) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => DishFormScreen.create(seed: seed)));
    if (mounted) Navigator.of(context).pop(saved ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _step != _Step.pick;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nuevo plato')),
        body: SafeArea(child: busy ? _buildProgress() : _buildPicker()),
      ),
    );
  }

  Widget _buildProgress() {
    final theme = Theme.of(context);
    final analyzing = _step == _Step.analyzing;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(_photo!.bytes, height: 220, fit: BoxFit.cover),
              ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(analyzing ? 'Analizando con IA…' : 'Subiendo foto…', style: theme.textTheme.titleMedium),
            if (analyzing) ...[
              const SizedBox(height: 8),
              Text(
                'Estamos identificando el plato, sus ingredientes y posibles alérgenos.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPicker() {
    final theme = Theme.of(context);
    final camera = cameraSupported();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.photo_camera_outlined, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Fotografía tu plato', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'La IA sugerirá nombre, descripción, ingredientes, alérgenos y calorías. '
                'Tú revisas y editas todo antes de publicar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'JPEG o PNG, máximo 10 MB.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (camera) ...[
                FilledButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Tomar foto'),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.tonalIcon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir de la galería'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _openForm(const DishFormSeed()),
                child: const Text('Continuar sin foto (completar manualmente)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
