class UserModel{
  UserModel({
    this.token,
    this.id,
    this.login,
    this.email,
    this.password,
  });

  late String? token;
  late String? id;
  late String? login;
  late String? email;
  late String? password;

  Map<String, dynamic> toJsonForRegistration(){
    return{
      "login":login,
      "email":email,
      "password":password,
    };
  }

  factory UserModel.fromJsonForRegistration(Map<String, dynamic> json){
    return UserModel(
      token: json["token"] ?? "",
      id: json["id"] ?? "",
      login: json["login"] ?? "",
      email: json["email"] ?? "",
      password: json["password"] ?? "",
    );
  }
}