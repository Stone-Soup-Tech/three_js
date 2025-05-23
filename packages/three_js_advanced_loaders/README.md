# three_js_advanced_loaders

[![Pub Version](https://img.shields.io/pub/v/three_js_advanced_loaders)](https://pub.dev/packages/three_js_advanced_loaders)
[![analysis](https://github.com/Knightro63/three_js/actions/workflows/flutter.yml/badge.svg)](https://github.com/Knightro63/three_js/actions/)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A type of three_js model loader that allows users to add either gltf, glb, or fbx files to thier projects.

![Gif multiple gltf models.](https://raw.githubusercontent.com/Knightro63/three_js/master/packages/three_js_advanced_loaders/assets/example.gif)

This is a dart conversion of three.js and three_dart, originally created by [@mrdoob](https://github.com/mrdoob) and has a coverted dart fork by [@wasabia](https://github.com/wasabia).

### Getting started

To get started add this to your pubspec.yaml file along with the other portions three_js_math, three_js_core, three_js_animations, and three_js_core_loaders.

```dart
    late Scene scene;

    void init() {
        scene = Scene();
        scene.background = Color.fromHex32(0xf0f0f0);
            
        final loader = GLTFLoader();
        final gltf = await loader.fromAsset('assets/${fileName}.glb');

        mesh = gltf!.scene.children[0];
        mesh.scale.setValues(1.5, 1.5, 1.5);
        scene.add(mesh);
    }
```

## Usage

This project is a more advanced model loader for three_js.

## Example

Find the example for this API [here](https://github.com/Knightro63/three_js/tree/main/packages/three_js_advanced_loaders/example/lib/main.dart).

## Contributing

Contributions are welcome.
In case of any problems look at [existing issues](https://github.com/Knightro63/three_js/issues), if you cannot find anything related to your problem then open an issue.
Create an issue before opening a [pull request](https://github.com/Knightro63/three_js/pulls) for non trivial fixes.
In case of trivial fixes open a [pull request](https://github.com/Knightro63/three_js/pulls) directly.
