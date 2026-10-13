import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _kCompany = 'req_company';
  static const String _kDirector = 'req_director';
  static const String _kMechanicGenitive = 'req_mechanic_genitive';
  static const String _kMechanicNominative = 'req_mechanic_nominative';

  static const String _defCompany = 'ООО "Агама-строй"';
  static const String _defDirector = 'Генералову С.И.';
  static const String _defMechanicGenitive = 'Ефимова И.В.';
  static const String _defMechanicNominative = 'Ефимов И.В.';

  final _companyCtrl = TextEditingController();
  final _directorCtrl = TextEditingController();
  final _mechanicGenCtrl = TextEditingController();
  final _mechanicNomCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _companyCtrl.text = prefs.getString(_kCompany) ?? _defCompany;
    _directorCtrl.text = prefs.getString(_kDirector) ?? _defDirector;
    _mechanicGenCtrl.text =
        prefs.getString(_kMechanicGenitive) ?? _defMechanicGenitive;
    _mechanicNomCtrl.text =
        prefs.getString(_kMechanicNominative) ?? _defMechanicNominative;
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompany, _companyCtrl.text.trim());
    await prefs.setString(_kDirector, _directorCtrl.text.trim());
    await prefs.setString(_kMechanicGenitive, _mechanicGenCtrl.text.trim());
    await prefs.setString(_kMechanicNominative, _mechanicNomCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Настройки сохранены')));
  }

  Future<void> _resetToDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Вернуть по умолчанию?'),
        content: const Text(
          'Текущие настройки будут заменены на значения по умолчанию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Вернуть'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _companyCtrl.text = _defCompany;
    _directorCtrl.text = _defDirector;
    _mechanicGenCtrl.text = _defMechanicGenitive;
    _mechanicNomCtrl.text = _defMechanicNominative;
    await _save();
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _directorCtrl.dispose();
    _mechanicGenCtrl.dispose();
    _mechanicNomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1B5E20).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Реквизиты заявки на закупку',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _field(
                  controller: _companyCtrl,
                  label: 'Название организации',
                  hint: 'ООО "Агама-строй"',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _field(
                  controller: _directorCtrl,
                  label: 'Директор (кому адресована заявка)',
                  hint: 'Генералову С.И.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _field(
                  controller: _mechanicGenCtrl,
                  label: 'Механик — в родительном падеже',
                  hint: 'Ефимова И.В.  (для шапки: "от механика ...")',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _field(
                  controller: _mechanicNomCtrl,
                  label: 'Механик — в именительном падеже',
                  hint: 'Ефимов И.В.  (для подписи)',
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Сохранение...' : 'Сохранить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore),
                    label: const Text('Вернуть по умолчанию'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Эти данные автоматически подставляются в PDF-заявку '
                    'на закупку. Изменения вступят в силу при следующем '
                    'формировании заявки.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: isDark,
        fillColor: isDark ? Colors.grey.shade900 : null,
      ),
      maxLines: null,
    );
  }
}
