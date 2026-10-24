import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'components.dart';
import 'theme.dart';

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  int mode = 0;
  final kj = TextEditingController();
  final basis = TextEditingController(text: '100');
  final basisKj = TextEditingController();
  final package = TextEditingController();

  @override
  void dispose() {
    kj.dispose();
    basis.dispose();
    basisKj.dispose();
    package.dispose();
    super.dispose();
  }

  double? get baseResult {
    final value = double.tryParse(kj.text.trim());
    if (value == null || value < 0) return null;
    return value / 4.184;
  }

  double? get packageResult {
    final serving = double.tryParse(basis.text.trim());
    final energy = double.tryParse(basisKj.text.trim());
    final size = double.tryParse(package.text.trim());
    if (serving == null ||
        serving <= 0 ||
        energy == null ||
        energy < 0 ||
        size == null ||
        size <= 0) {
      return null;
    }
    return energy / 4.184 * size / serving;
  }

  double? get servingKcal {
    final energy = double.tryParse(basisKj.text.trim());
    if (energy == null || energy < 0) return null;
    return energy / 4.184;
  }

  void _setKj(String value) {
    setState(() => kj.text = value);
  }

  @override
  Widget build(BuildContext context) {
    final value = mode == 0 ? baseResult : packageResult;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBackButton(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                    children: [
                      const PageHeader(eyebrow: '对着营养成分表', title: '热量换算'),
                      const SizedBox(height: 14),
                      const Text(
                        '千焦换成大卡，也能把整包的热量一次算清。数字来自包装，换算只改变单位。',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.7,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PillSegmented<int>(
                        value: mode,
                        onChanged: (next) => setState(() => mode = next),
                        options: const [
                          SegmentedOption(value: 0, label: '千焦转大卡'),
                          SegmentedOption(value: 1, label: '整包热量'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      if (mode == 0)
                        _Field(
                          label: '营养成分表能量',
                          controller: kj,
                          hint: '例如 418.4',
                          suffix: '千焦 kJ',
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                        )
                      else ...[
                        _Field(
                          label: '营养成分表能量',
                          controller: basisKj,
                          hint: '每份对应的千焦',
                          suffix: '千焦 kJ',
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: '每份分量',
                                controller: basis,
                                hint: '100',
                                suffix: 'g / ml',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Field(
                                label: '整包净含量',
                                controller: package,
                                hint: '例如 250',
                                suffix: 'g / ml',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (mode == 0) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _QuickValue(
                              label: '500 千焦',
                              onTap: () => _setKj('500'),
                            ),
                            const SizedBox(width: 8),
                            _QuickValue(
                              label: '1000 千焦',
                              onTap: () => _setKj('1000'),
                            ),
                            const SizedBox(width: 8),
                            _QuickValue(
                              label: '2000 千焦',
                              onTap: () => _setKj('2000'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      _ResultCard(
                        value: value,
                        label: mode == 0 ? '约合' : '整包约',
                        detail: mode == 0
                            ? '按 1 大卡 = 4.184 千焦换算'
                            : _packageDetail(),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '国内营养成分表通常使用千焦。换算只改变单位，不代表食物本身的热量。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.65,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _packageDetail() {
    final serving = double.tryParse(basis.text.trim());
    final size = double.tryParse(package.text.trim());
    final perServing = servingKcal;
    if (perServing == null || serving == null || size == null) {
      return '填写每份分量和整包净含量后自动计算';
    }
    return '每 ${formatNumber(serving)} g/ml 约 ${formatCalories(perServing)} 大卡 · 整包 ${formatNumber(size)} g/ml';
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.suffix,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(hintText: hint, suffixText: suffix),
        ),
      ],
    );
  }
}

class _QuickValue extends StatelessWidget {
  const _QuickValue({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.95,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.glassStrong,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.value,
    required this.label,
    required this.detail,
  });

  final double? value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      elevated: true,
      borderColor: const Color(0x38FFFFFF),
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      child: Stack(
        children: [
          Positioned(
            right: -66,
            top: -88,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x14FFFFFF), width: 24),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: AppColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    CupertinoIcons.bolt_fill,
                    size: 15,
                    color: AppColors.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value == null ? '—' : formatCalories(value!),
                    style: const TextStyle(
                      fontSize: 54,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -2.2,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      '大卡',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
