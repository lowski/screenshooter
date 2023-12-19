# example

Example for the screenshooter tool.

## Running the example

If you wanna do that, here's how:

- `flutter create . --platforms ios` to add the `ios` folder first.
- Ensure that you have the correct simulator from the `screenshooter.yaml` file installed. (You can use `dart run screenshooter:create_simulators` to create the simulators from the config.)
- `dart run screenshooter` to take the screenshots.
- Make sure you have ImageMagick installed.
- `dart run screenshooter:frame` to frame the screenshots.

Done. The screenshots of the example app are in the `./screenshots/` folder.
