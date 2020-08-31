class SockyUser {
  String id; // TODO REmove, maybe just keep ID
  String name;

  SockyUser({this.id, this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
