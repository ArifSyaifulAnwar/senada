class PinLoginModel {
  final String userId;
  final String deviceId;
  final bool isPinEnabled;
  final String? pinCode;

  PinLoginModel({
    required this.userId,
    required this.deviceId,
    required this.isPinEnabled,
    this.pinCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'isPinEnabled': isPinEnabled,
      'pinCode': pinCode,
    };
  }

  factory PinLoginModel.fromJson(Map<String, dynamic> json) {
    return PinLoginModel(
      userId: json['userId'],
      deviceId: json['deviceId'],
      isPinEnabled: json['isPinEnabled'],
      pinCode: json['pinCode'],
    );
  }
}
