import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_exception.dart';
import '../../api/error_messages.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../utils/photo_picker.dart';
import '../../widgets/dish_widgets.dart';
import '../../widgets/state_views.dart';
import 'model_picker.dart';

/// Datos iniciales para un plato nuevo (foto subida + sugerencias de IA).
class DishFormSeed {
  const DishFormSeed({this.photoId, this.photoUrl, this.photoBytes, this.analysis, this.notice});

  final String? photoId;
  final String? photoUrl;
  final Uint8List? photoBytes;
  final Analysis? analysis;

  /// Aviso a mostrar arriba del formulario (p. ej. IA no disponible).
  final String? notice;

  DishFormSeed withAnalysis(Analysis a) =>
      DishFormSeed(photoId: photoId, photoUrl: photoUrl, photoBytes: photoBytes, analysis: a, notice: notice);

  DishFormSeed withNotice(String n) =>
      DishFormSeed(photoId: photoId, photoUrl: photoUrl, photoBytes: photoBytes, analysis: analysis, notice: n);
}

/// Nombres legibles de los campos que el backend devuelve en `details`.
const _fieldLabels = {
  'name': 'Nombre',
  'description': 'Descripción',
  'category': 'Categoría',
  'priceSoles': 'Precio',
  'price': 'Precio',
  'photo': 'Foto',
  'photoId': 'Foto',
  'photoUrl': 'Foto',
  'model': 'Modelo 3D',
  'modelId': 'Modelo 3D',
  'allergens': 'Alérgenos',
  'allergenFree': 'Alérgenos',
  'caloriesMin': 'Calorías',
  'caloriesMax': 'Calorías',
  'ingredients': 'Ingredientes',
  'kitchenNotes': 'Notas de cocina',
};

/// Ficha del plato (US09) con selector de modelo 3D (US10).
class DishFormScreen extends StatefulWidget {
  const DishFormScreen.create({super.key, required DishFormSeed this.seed}) : dish = null;

  const DishFormScreen.edit({super.key, required Dish this.dish}) : seed = null;

  final DishFormSeed? seed;
  final Dish? dish;

  bool get isEdit => dish != null;

  @override
  State<DishFormScreen> createState() => _DishFormScreenState();
}

class _DishFormScreenState extends State<DishFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _ingredientInput = TextEditingController();
  final _calMin = TextEditingController();
  final _calMax = TextEditingController();
  final _kitchenNotes = TextEditingController();

  final List<String> _ingredients = [];
  final Set<String> _allergens = {};
  bool _allergenFree = false;
  bool _vegetarian = false;
  bool _vegan = false;
  String? _modelId;

  String? _dishId;
  DishStatus _status = DishStatus.draft;
  String? _photoId; // solo si hay foto nueva por enviar
  String? _photoUrl;
  Uint8List? _photoBytes;
  bool _uploadingPhoto = false;

  List<Allergen>? _allergenCatalog;
  List<String> _categories = const [];
  List<Model3D>? _models;
  String? _catalogError;

  bool _saving = false;
  bool _validatingForPublish = false;
  bool _dirty = false;
  bool _savedSomething = false;
  String? _notice;
  String? _generalError;
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    final dish = widget.dish;
    final seed = widget.seed;
    if (dish != null) {
      _dishId = dish.id;
      _status = dish.status;
      _name.text = dish.name;
      _description.text = dish.description ?? '';
      _category.text = dish.category;
      _price.text = dish.priceSoles > 0 ? dish.priceSoles.toStringAsFixed(2) : '';
      _ingredients.addAll(dish.ingredients);
      _allergens.addAll(dish.allergens);
      _allergenFree = dish.allergenFree;
      _calMin.text = dish.calories?.min?.toString() ?? '';
      _calMax.text = dish.calories?.max?.toString() ?? '';
      _kitchenNotes.text = dish.kitchenNotes ?? '';
      _vegetarian = dish.vegetarian;
      _vegan = dish.vegan;
      _modelId = dish.model?.id;
      _photoUrl = dish.photoUrl;
    } else if (seed != null) {
      _photoId = seed.photoId;
      _photoUrl = seed.photoUrl;
      _photoBytes = seed.photoBytes;
      _notice = seed.notice;
      final a = seed.analysis;
      if (a != null) {
        _name.text = a.suggestedName ?? '';
        _description.text = a.description ?? '';
        _category.text = a.category ?? '';
        _ingredients.addAll(a.ingredients);
        _allergens.addAll(a.allergens);
        _calMin.text = a.estimatedCalories?.min?.toString() ?? '';
        _calMax.text = a.estimatedCalories?.max?.toString() ?? '';
        _modelId = a.suggestedModelId;
      }
      _dirty = true; // la foto ya se subió: confirmar antes de descartar
    }
    for (final c in [_name, _description, _category, _price, _calMin, _calMax, _kitchenNotes]) {
      c.addListener(_markDirty);
    }
    _loadCatalogs();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _category, _price, _ingredientInput, _calMin, _calMax, _kitchenNotes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    final api = SessionScope.read(context).api;
    setState(() => _catalogError = null);
    try {
      final results = await Future.wait([api.allergens(), api.categories(), api.models()]);
      if (!mounted) return;
      setState(() {
        _allergenCatalog = results[0] as List<Allergen>;
        _categories = results[1] as List<String>;
        _models = results[2] as List<Model3D>;
      });
    } catch (e) {
      if (mounted) setState(() => _catalogError = 'No se pudieron cargar los catálogos. ${friendlyError(e)}');
    }
  }

  // ---------- Foto ----------

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cameraSupported())
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final api = SessionScope.read(context).api;
    try {
      final photo = await pickPhoto(source);
      if (photo == null || !mounted) return;
      setState(() => _uploadingPhoto = true);
      final uploaded = await api.uploadPhoto(photo.bytes, fileName: photo.fileName, contentType: photo.mimeType);
      if (!mounted) return;
      setState(() {
        _photoId = uploaded.photoId;
        _photoUrl = uploaded.photoUrl;
        _photoBytes = photo.bytes;
        _dirty = true;
        _serverErrors = Map.of(_serverErrors)
          ..remove('photo')
          ..remove('photoId');
      });
    } on PhotoValidationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ---------- Ingredientes / alérgenos ----------

  void _addIngredients(String raw) {
    final items = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final i in items) {
        if (!_ingredients.any((x) => x.toLowerCase() == i.toLowerCase())) _ingredients.add(i);
      }
      _ingredientInput.clear();
      _dirty = true;
    });
  }

  void _toggleAllergen(String code, bool selected) {
    setState(() {
      selected ? _allergens.add(code) : _allergens.remove(code);
      if (selected) _allergenFree = false;
      _dirty = true;
    });
  }

  void _setAllergenFree(bool value) {
    setState(() {
      _allergenFree = value;
      if (value) _allergens.clear();
      _dirty = true;
    });
  }

  // ---------- Guardar / publicar ----------

  DishInput _buildInput() {
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return DishInput(
      name: _name.text.trim(),
      description: opt(_description),
      category: _category.text.trim(),
      priceSoles: parseDecimal(_price.text) ?? 0,
      ingredients: List.of(_ingredients),
      allergens: _allergenFree ? const [] : _allergens.toList(),
      allergenFree: _allergenFree,
      kitchenNotes: opt(_kitchenNotes),
      caloriesMin: int.tryParse(_calMin.text.trim()),
      caloriesMax: int.tryParse(_calMax.text.trim()),
      vegetarian: _vegetarian,
      vegan: _vegan,
      photoId: _photoId,
      modelId: _modelId,
    );
  }

  bool _validate({required bool forPublish}) {
    _validatingForPublish = forPublish;
    setState(() {
      _serverErrors = const {};
      _generalError = null;
    });
    final ok = _formKey.currentState!.validate();
    if (!ok) showSnack(context, 'Revisa los campos marcados.', error: true);
    return ok;
  }

  Future<Dish> _persist() async {
    final api = SessionScope.read(context).api;
    final input = _buildInput();
    final id = _dishId;
    final dish = id == null ? await api.createDish(input) : await api.updateDish(id, input);
    _dishId = dish.id;
    _status = dish.status;
    _photoId = null; // ya quedó asociada al plato
    _savedSomething = true;
    _dirty = false;
    return dish;
  }

  Future<void> _saveDraft() async {
    if (_saving || !_validate(forPublish: false)) return;
    setState(() => _saving = true);
    try {
      await _persist();
      if (!mounted) return;
      showSnack(context, widget.isEdit ? 'Cambios guardados' : 'Borrador guardado');
      Navigator.of(context).pop(true);
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publish() async {
    if (_saving || !_validate(forPublish: true)) return;
    final api = SessionScope.read(context).api;
    setState(() => _saving = true);
    try {
      final dish = await _persist();
      final published = await api.publishDish(dish.id);
      _status = published.status;
      if (!mounted) return;
      showSnack(context, '¡${published.name} ya está publicado en tu carta!');
      Navigator.of(context).pop(true);
    } catch (e) {
      _handleError(e, afterSave: _savedSomething);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _handleError(Object e, {bool afterSave = false}) {
    if (!mounted) return;
    setState(() {
      if (e is ApiException && (e.code == 'DISH_NOT_PUBLISHABLE' || e.code == 'VALIDATION_ERROR')) {
        _serverErrors = e.fieldErrors;
        _generalError = e.code == 'DISH_NOT_PUBLISHABLE'
            ? (afterSave
                ? 'Se guardó como borrador, pero aún no se puede publicar:'
                : 'Aún no se puede publicar:')
            : 'Revisa los siguientes campos:';
        if (_serverErrors.isEmpty) _generalError = e.message;
      } else {
        _generalError = friendlyError(e);
      }
    });
    _formKey.currentState?.validate();
    showSnack(
      context,
      _serverErrors.isNotEmpty ? 'Revisa los detalles indicados en la ficha.' : _generalError ?? friendlyError(e),
      error: true,
    );
  }

  Future<void> _delete() async {
    final id = _dishId;
    if (id == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar plato',
      message: '¿Eliminar "${_name.text}" de tu carta? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await SessionScope.read(context).api.deleteDish(id);
      if (!mounted) return;
      showSnack(context, 'Plato eliminado');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final ok = await confirmDialog(
      context,
      title: '¿Descartar cambios?',
      message: widget.isEdit || _savedSomething
          ? 'Los cambios que no guardaste se perderán.'
          : 'Se perderán los datos de este plato.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop(_savedSomething);
  }

  // ---------- UI ----------

  String? _serverError(List<String> keys) {
    for (final k in keys) {
      final m = _serverErrors[k];
      if (m != null) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isPublished = _status == DishStatus.published;
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Editar plato' : 'Nuevo plato'),
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close),
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          ),
          actions: [
            if (widget.isEdit)
              IconButton(
                tooltip: 'Eliminar plato',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (_notice != null) _NoticeCard(message: _notice!, onClose: () => setState(() => _notice = null)),
              if (widget.seed?.analysis != null) _AiCard(analysis: widget.seed!.analysis!),
              if (_generalError != null) _ErrorSummary(title: _generalError!, errors: _serverErrors),
              if (widget.isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [const Text('Estado: '), StatusChip(status: _status)]),
                ),
              _buildPhoto(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Nombre del plato *', errorText: _serverError(['name'])),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descripción', alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCategoryField()),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(
                        labelText: 'Precio *',
                        prefixText: 'S/ ',
                        errorText: _serverError(['priceSoles', 'price']),
                      ),
                      validator: (v) {
                        final p = parseDecimal(v ?? '');
                        if (p == null) return 'Ingresa el precio';
                        if (p < 0) return 'Precio no válido';
                        if (_validatingForPublish && p <= 0) return 'Debe ser mayor a 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_catalogError != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _catalogError!, onRetry: _loadCatalogs),
              ],
              _section('Ingredientes'),
              _buildIngredients(),
              _section('Alérgenos *', error: _serverError(['allergens', 'allergenFree'])),
              _buildAllergens(),
              _section('Calorías'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _calMin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Mínimo', suffixText: 'kcal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _calMax,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Máximo', suffixText: 'kcal'),
                      validator: (v) {
                        final min = int.tryParse(_calMin.text);
                        final max = int.tryParse(v ?? '');
                        if (min != null && max != null && max < min) return 'Debe ser ≥ mínimo';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Estimación orientativa; no reemplaza un análisis nutricional.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vegetariano'),
                value: _vegetarian,
                onChanged: (v) => setState(() {
                  _vegetarian = v;
                  if (!v) _vegan = false;
                  _dirty = true;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vegano'),
                value: _vegan,
                onChanged: (v) => setState(() {
                  _vegan = v;
                  if (v) _vegetarian = true;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _kitchenNotes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas de cocina',
                  alignLabelWithHint: true,
                  helperText: 'Advierte riesgos de contaminación cruzada '
                      '(p. ej. «se fríe en el mismo aceite que los mariscos»).',
                  helperMaxLines: 3,
                ),
              ),
              _section('Modelo 3D para realidad aumentada', error: _serverError(['model', 'modelId'])),
              ModelPicker(
                models: _models,
                selectedId: _modelId,
                category: _category.text.trim(),
                onSelected: (id) => setState(() {
                  _modelId = id;
                  _dirty = true;
                }),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving || _uploadingPhoto ? null : _saveDraft,
                    child: Text(widget.isEdit ? 'Guardar cambios' : 'Guardar borrador'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving || _uploadingPhoto ? null : _publish,
                    icon: _saving
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.public),
                    label: Text(isPublished ? 'Guardar y publicar' : 'Publicar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, {String? error}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    final theme = Theme.of(context);
    final error = _serverError(['photo', 'photoId', 'photoUrl']);
    final Widget image = _photoBytes != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_photoBytes!, width: 96, height: 96, fit: BoxFit.cover),
          )
        : DishPhoto(url: _photoUrl, size: 96, radius: 12);
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [image, if (_uploadingPhoto) const CircularProgressIndicator()],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_photoUrl == null && _photoBytes == null) ? 'Sin foto' : 'Foto del plato',
                style: theme.textTheme.titleSmall,
              ),
              if (error != null)
                Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _uploadingPhoto || _saving ? null : _changePhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text((_photoUrl == null && _photoBytes == null) ? 'Agregar foto' : 'Cambiar foto'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return TextFormField(
      controller: _category,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}), // reordena los modelos sugeridos
      decoration: InputDecoration(
        labelText: 'Categoría *',
        errorText: _serverError(['category']),
        suffixIcon: _categories.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Elegir categoría',
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (c) {
                  _category.text = c;
                  setState(() {});
                },
                itemBuilder: (_) => [for (final c in _categories) PopupMenuItem(value: c, child: Text(c))],
              ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Elige o escribe una categoría' : null,
    );
  }

  Widget _buildIngredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ingredientInput,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: _addIngredients,
          decoration: InputDecoration(
            hintText: 'Agregar ingrediente (separa varios con comas)',
            suffixIcon: IconButton(
              tooltip: 'Agregar',
              icon: const Icon(Icons.add),
              onPressed: () => _addIngredients(_ingredientInput.text),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_ingredients.isEmpty)
          Text('Sin ingredientes', style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final i in _ingredients)
                InputChip(
                  label: Text(i),
                  onDeleted: () => setState(() {
                    _ingredients.remove(i);
                    _dirty = true;
                  }),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildAllergens() {
    final catalog = _allergenCatalog;
    if (catalog == null && _catalogError == null) {
      return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    }
    final known = {for (final a in catalog ?? const <Allergen>[]) a.code: a};
    final codes = [...known.keys, ..._allergens.where((c) => !known.containsKey(c))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final code in codes)
              FilterChip(
                label: Text(_allergenLabel(known[code], code)),
                selected: _allergens.contains(code),
                onSelected: _allergenFree && !_allergens.contains(code) ? null : (v) => _toggleAllergen(code, v),
              ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Libre de alérgenos'),
          subtitle: const Text('Declaro que este plato no contiene ninguno de los alérgenos listados.'),
          value: _allergenFree,
          onChanged: (v) => _setAllergenFree(v ?? false),
        ),
      ],
    );
  }

  String _allergenLabel(Allergen? a, String code) {
    if (a == null) return code;
    final icon = a.icon;
    // Solo mostramos el ícono si es un emoji/carácter corto.
    if (icon != null && icon.isNotEmpty && icon.runes.length <= 2) return '$icon ${a.label}';
    return a.label;
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
        title: Text(message, style: TextStyle(color: scheme.onSecondaryContainer)),
        trailing: IconButton(tooltip: 'Cerrar', onPressed: onClose, icon: const Icon(Icons.close)),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (analysis.confidence * 100).round();
    return Card(
      color: scheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
        title: Text('Sugerencias generadas con IA', style: TextStyle(color: scheme.onTertiaryContainer)),
        subtitle: Text(
          'Confianza $pct %. Revisa y corrige todo antes de publicar, en especial los alérgenos.',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

class _ErrorSummary extends StatelessWidget {
  const _ErrorSummary({required this.title, required this.errors});

  final String title;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(color: scheme.onErrorContainer);
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: style.copyWith(fontWeight: FontWeight.w700)),
            for (final e in errors.entries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${_fieldLabels[e.key] ?? e.key}: ${e.value}', style: style),
              ),
          ],
        ),
      ),
    );
  }
}
