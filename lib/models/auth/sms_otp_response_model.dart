class SMSOTPResponseModel {
  final bool isSuccess;
  final String message;

  SMSOTPResponseModel({required this.isSuccess, required this.message});

  factory SMSOTPResponseModel.fromJson(Map<String, dynamic> json) {
    return SMSOTPResponseModel(
      isSuccess: json['return']['status'] == 200,
      message: json['return']['message'],
    );
  }
}
