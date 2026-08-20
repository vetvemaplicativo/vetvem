import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/input_formatters.dart';
import '../register_controller.dart';

class Step3Address extends GetView<RegisterController> {
  const Step3Address({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: controller.formStep3Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text('Seu endereço',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text('Onde o profissional vai atender',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),

            // CEP
            Obx(() => TextFormField(
                  controller: controller.cepController,
                  validator: controller.validateCep,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [CepInputFormatter()],
                  onChanged: (_) => controller.lookupCep(),
                  decoration: InputDecoration(
                    hintText: 'CEP',
                    suffixIcon: controller.isLoadingCep.value
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                )),
            const SizedBox(height: 14),

            // Rua + Número
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: controller.streetController,
                    validator: controller.validateRequired,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Rua'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: controller.numberController,
                    validator: controller.validateRequired,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Nº'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.complementController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Complemento'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.neighborhoodController,
              validator: controller.validateRequired,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Bairro'),
            ),
            const SizedBox(height: 14),

            // Cidade + Estado
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: controller.cityController,
                    validator: controller.validateRequired,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'Cidade'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: controller.stateController,
                    validator: controller.validateRequired,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      hintText: 'UF',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: controller.referenceController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => controller.proceedFromStep3(),
              decoration:
                  const InputDecoration(hintText: 'Ponto de referência'),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: controller.proceedFromStep3,
              child: const Text('Próximo'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
