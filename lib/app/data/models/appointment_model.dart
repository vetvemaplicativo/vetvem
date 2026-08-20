enum AppointmentStatus { scheduled, confirmed, completed, cancelled }

class AppointmentModel {
  final String id;
  final String vetId;
  final String vetName;
  final String vetSpecialty;
  final String petName;
  final String petType;
  final DateTime dateTime;
  final String address;
  final AppointmentStatus status;
  final double price;
  final String? notes;
  final String petPhotoBase64;

  const AppointmentModel({
    required this.id,
    required this.vetId,
    required this.vetName,
    required this.vetSpecialty,
    required this.petName,
    required this.petType,
    required this.dateTime,
    required this.address,
    required this.status,
    required this.price,
    this.notes,
    this.petPhotoBase64 = '',
  });

  String get statusLabel {
    switch (status) {
      case AppointmentStatus.scheduled:
        return 'Agendado';
      case AppointmentStatus.confirmed:
        return 'Confirmado';
      case AppointmentStatus.completed:
        return 'Concluído';
      case AppointmentStatus.cancelled:
        return 'Cancelado';
    }
  }
}
