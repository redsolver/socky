# Socky

Full-Stack Framework for Flutter and Dart. Write code instead of HTTP endpoints.

## Get started

1. Make sure you have Flutter and Dart installed
2. Run `pub global activate socky_cli`
3. Run `socky init my_project` in a folder of your choice
4. Change your working directory (`cd my_project`)
5. Run `socky watch`
6. Wait until `server` and `shared` are built.
7. Open a new terminal window
8. Run `socky dev` in your project's directory
9. Run the flutter app located in the `app` subfolder

## TODO

- Allow API versioning
  Example:
  TodosSocket = /api/v1.2.3/todos
  domain.tld/socky/v1.2.3
- Use GET method when method name starts with "get"