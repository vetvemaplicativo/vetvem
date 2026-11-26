import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/vv2/vv2_tokens.dart';
import '../../../../utils/input_formatters.dart';
import '../../../../widgets/auth_widgets.dart';
import '../register_controller.dart';
import 'register_widgets.dart';

class Step3Address extends GetView<RegisterController> {
  const Step3Address({super.key});

  @override
  Widget build(BuildContext context) {
    TextFormField field(TextEditingController c, String label,
            {String? Function(String?)? validator,
            TextCapitalization cap = TextCapitalization.words,
            TextInputType? type,
            int? maxLength,
            TextInputAction action = TextInputAction.next,
            ValueChanged<String>? onSubmitted}) =>
        TextFormField(
          controller: c,
          validator: validator,
          textCapitalization: cap,
          keyboardType: type,
          maxLength: maxLength,
          textInputAction: action,
          onFieldSubmitted: onSubmitted,
          style: Vv2.bodyLarge,
          decoration: regDecoration(label),
        );

    return RegScroll(
      child: Form(
        key: controller.formStep3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            regSubtitle('Onde o profissional vai atender'),
            // CEP: erro de "não encontrado" fica logo abaixo do campo.
            Obx(() => TextFormField(
                  controller: controller.cepController,
                  validator: controller.validateCep,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [CepInputFormatter()],
                  onChanged: (_) => controller.lookupCep(),
                  style: Vv2.bodyLarge,
                  decoration: regDecoration(
                    'CEP',
                    errorText: controller.cepError.value.isEmpty
                        ? null
                        : controller.cepError.value,
                    suffix: controller.isLoadingCep.value
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Vv2.primary),
                            ),
                          )
                        : null,
                  ),
                )),
            const SizedBox(height: 14),
            RegPair(
              a: field(controller.streetController, 'Rua',
                  validator: controller.validateRequired),
              b: field(controller.numberController, 'Nº',
                  validator: controller.validateRequired,
                  cap: TextCapitalization.none),
            ),
            const SizedBox(height: 14),
            field(controller.complementController, 'Complemento',
                cap: TextCapitalization.sentences),
            const SizedBox(height: 14),
            field(controller.neighborhoodController, 'Bairro',
                validator: controller.validateRequired),
            const SizedBox(height: 14),
            RegPair(
              a: field(controller.cityController, 'Cidade',
                  validator: controller.validateRequired),
              b: field(controller.stateController, 'UF',
                  validator: controller.validateRequired,
                  cap: TextCapitalization.characters,
                  maxLength: 2),
            ),
            const SizedBox(height: 14),
            field(controller.referenceController, 'Ponto de referência',
                cap: TextCapitalization.sentences,
                action: TextInputAction.done,
                onSubmitted: (_) => controller.proceedFromStep3()),
            const SizedBox(height: 28),
            VvPillButton(label: 'Próximo', onTap: controller.proceedFromStep3),
          ],
        ),
      ),
    );
  }
}
