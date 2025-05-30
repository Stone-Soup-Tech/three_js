part of three_webgl;

class UniformsCache {
  UniformsCache();

  Map<int, Map<String, dynamic>> lights = {};

  void dispose(){
    lights.clear();
  }

  Map<String, dynamic> get(light) {
    if (lights[light.id] != null) {
      return lights[light.id]!;
    }

    Map<String, dynamic>? uniforms;

    switch (light.type) {
      case 'DirectionalLight':
        uniforms = {"direction": Vector3.zero(), "color": Color(0, 0, 0)};
        break;

      case 'SpotLight':
        uniforms = {
          "position": Vector3.zero(),
          "direction": Vector3.zero(),
          "color": Color(0, 0, 0),
          "distance": 0,
          "coneCos": 0,
          "penumbraCos": 0,
          "decay": 0
        };
        break;

      case 'PointLight':
        uniforms = {"position": Vector3.zero(), "color": Color(1, 1, 1), "distance": 0, "decay": 0};
        break;

      case 'HemisphereLight':
        uniforms = {"direction": Vector3.zero(), "skyColor": Color(0, 0, 0), "groundColor": Color(0, 0, 0)};
        break;

      case 'RectAreaLight':
        uniforms = {
          "color": Color(0, 0, 0),
          "position": Vector3.zero(),
          "halfWidth": Vector3.zero(),
          "halfHeight": Vector3.zero()
        };
        break;
    }

    lights[light.id] = uniforms!;

    return uniforms;
  }
}

class ShadowUniformsCache {
  Map<int, Map<String, dynamic>> lights = {};

  void dispose(){
    lights.clear();
  }

  Map<String, dynamic>? get(light) {
    if (lights[light.id] != null) {
      return lights[light.id];
    }

    Map<String, dynamic> uniforms = {};

    switch (light.type) {
      case 'DirectionalLight':
        uniforms = {
          "shadowIntensity": 1,
          "shadowBias": 0, 
          "shadowNormalBias": 0, 
          "shadowRadius": 1, 
          "shadowMapSize": Vector2.zero()
        };
        break;

      case 'SpotLight':
        uniforms = {
          'shadowIntensity': 1,
          "shadowBias": 0, 
          "shadowNormalBias": 0, 
          "shadowRadius": 1, 
          "shadowMapSize": Vector2.zero()
        };
        break;

      case 'PointLight':
        uniforms = {
          'shadowIntensity': 1,
          "shadowBias": 0,
          "shadowNormalBias": 0,
          "shadowRadius": 1,
          "shadowMapSize": Vector2.zero(),
          "shadowCameraNear": 1,
          "shadowCameraFar": 1000
        };
        break;

      // TODO (abelnation): set RectAreaLight shadow uniforms

    }

    lights[light.id] = uniforms;

    return uniforms;
  }
}

int nextVersion = 0;

int shadowCastingAndTexturingLightsFirst(Light lightA, Light lightB) {
	return ( lightB.castShadow ? 2 : 0 ) - ( lightA.castShadow ? 2 : 0 ) + ( lightB.map != null? 1 : 0 ) - ( lightA.map != null? 1 : 0 );
}

class WebGLLights {
  late LightState state;
  late UniformsCache cache;
  late ShadowUniformsCache shadowCache;
  late Vector3 vector3;
  late Matrix4 matrix4;
  late Matrix4 matrix42;
  WebGLExtensions extensions;

  WebGLLights(this.extensions) {
    cache = UniformsCache();
    shadowCache = ShadowUniformsCache();

    state = LightState({
      "version": 0,
      "hash": {
        "directionalLength": -1,
        "pointLength": -1,
        "spotLength": -1,
        "rectAreaLength": -1,
        "hemiLength": -1,

        "numDirectionalShadows": -1,
        "numPointShadows": -1,
        "numSpotShadows": -1,
        'numSpotMaps': - 1,

        'numLightProbes': - 1
      },
      "ambient": List<double>.from([0.0, 0.0, 0.0]),
      "probe": [],
      "directional": [],
      "directionalShadow": [],
      "directionalShadowMap": [],
      "directionalShadowMatrix": [],
      "spot": [],
      'spotLightMap': [],
      "spotShadow": [],
      "spotShadowMap": [],
      "spotShadowMatrix": [],
      'spotLightMatrix': [],
      "rectArea": [],
      "rectAreaLTC1": null,
      "rectAreaLTC2": null,
      "point": [],
      "pointShadow": [],
      "pointShadowMap": [],
      "pointShadowMatrix": [],
      "hemi": [],
      'numSpotLightShadowsWithMaps': 0,
      'numLightProbes': 0
    });

    for (int i = 0; i < 9; i++) {
      state.probe.add(Vector3.zero());
    }

    vector3 = Vector3.zero();
    matrix4 = Matrix4.identity();
    matrix42 = Matrix4.identity();
  }

  void setup(List<Light> lights, [bool? physicallyCorrectLights]) {
    double r = 0.0;
    double g = 0.0;
    double b = 0.0;

    for (int i = 0; i < 9; i++) {
      state.probe[i].setValues(0, 0, 0);
    }

    int directionalLength = 0;
    int pointLength = 0;
    int spotLength = 0;
    int rectAreaLength = 0;
    int hemiLength = 0;

    int numDirectionalShadows = 0;
    int numPointShadows = 0;
    int numSpotShadows = 0;
		int numSpotMaps = 0;
		int numSpotShadowsWithMaps = 0;
		int numLightProbes = 0;

    lights.sort((a, b) => shadowCastingAndTexturingLightsFirst(a, b));

    // artist-friendly light intensity scaling factor
    double scaleFactor = (physicallyCorrectLights != true) ? math.pi : 1.0;

    for (int i = 0, l = lights.length; i < l; i++) {
      final light = lights[i];

      final color = light.color ?? Color();
      final intensity = light.intensity;
      final distance = light.distance;

      final shadowMap = (light.shadow != null && light.shadow!.map != null) ? light.shadow!.map!.texture : null;

      if (light is AmbientLight) {
        r += color.red * intensity;
        g += color.green * intensity;
        b += color.blue * intensity;
      } 
      else if (light is LightProbe) {
        for (int j = 0; j < 9; j++) {
          state.probe[j].addScaled(light.sh!.coefficients[j], intensity);
        }
      } 
      else if (light is DirectionalLight) {
        final uniforms = cache.get(light);

        (uniforms["color"] as Color)..setFrom(light.color!)..scale(light.intensity * scaleFactor);

        if (light.castShadow) {
          final shadow = light.shadow!;

          final shadowUniforms = shadowCache.get(light);

          shadowUniforms?["shadowIntensity"] = shadow.intensity;
          shadowUniforms?["shadowBias"] = shadow.bias;
          shadowUniforms?["shadowNormalBias"] = shadow.normalBias;
          shadowUniforms?["shadowRadius"] = shadow.radius;
          shadowUniforms?["shadowMapSize"] = shadow.mapSize;

          state.directionalShadow.listSetter(directionalLength, shadowUniforms);
          state.directionalShadowMap.listSetter(directionalLength, shadowMap);
          state.directionalShadowMatrix.listSetter( directionalLength, light.shadow!.matrix);

          numDirectionalShadows++;
        }

        state.directional.listSetter(directionalLength, uniforms);

        directionalLength++;
      } 
      else if (light is SpotLight) {
        final uniforms = cache.get(light);

        (uniforms["position"] as Vector3).setFromMatrixPosition(light.matrixWorld);
        (uniforms["color"] as Color)..setFrom(color)..scale(intensity * scaleFactor);

        uniforms["distance"] = distance;

        uniforms["coneCos"] = math.cos(light.angle!);
        uniforms["penumbraCos"] = math.cos(light.angle! * (1 - light.penumbra!));
        uniforms["decay"] = light.decay;

        state.spot.listSetter(spotLength, uniforms);
        final shadow = light.shadow!;

				if ( light.map != null) {
          state.spotLightMap.listSetter(numSpotMaps, light.map);
					numSpotMaps ++;

					// make sure the lightMatrix is up to date
					// TODO : do it if required only
					shadow.updateMatrices( light );
					if (light.castShadow) numSpotShadowsWithMaps ++;
				}

				state.spotLightMatrix.add(shadow.matrix);

        if (light.castShadow) {
          final shadowUniforms = shadowCache.get(light);
					
          shadowUniforms?['shadowIntensity'] = shadow.intensity;
          shadowUniforms?["shadowBias"] = shadow.bias;
          shadowUniforms?["shadowNormalBias"] = shadow.normalBias;
          shadowUniforms?["shadowRadius"] = shadow.radius;
          shadowUniforms?["shadowMapSize"] = shadow.mapSize;

          state.spotShadow.listSetter(spotLength, shadowUniforms);
          state.spotShadowMap.listSetter(spotLength, shadowMap);
          state.spotShadowMatrix.listSetter( spotLength, light.shadow!.matrix);

          numSpotShadows++;
        }

        spotLength++;
      } 
      else if (light is RectAreaLight) {
        final uniforms = cache.get(light);

        // (a) intensity is the total visible light emitted
        //uniforms.color.copy( color ).scale( intensity / ( light.width * light.height * math.PI ) );

        // (b) intensity is the brightness of the light
        uniforms["color"]..setFrom(color)..scale(intensity);

        uniforms["halfWidth"].setValues(light.width! * 0.5, 0.0, 0.0);
        uniforms["halfHeight"].setValues(0.0, light.height! * 0.5, 0.0);

        // state.rectArea[ rectAreaLength ] = uniforms;
        state.rectArea.listSetter(rectAreaLength, uniforms);

        rectAreaLength++;
      } 
      else if (light is PointLight) {
        final uniforms = cache.get(light);

        (uniforms["color"] as Color)..setFrom(light.color!)..scale(light.intensity * scaleFactor);
        uniforms["distance"] = light.distance ?? 0;
        uniforms["decay"] = light.decay;

        if (light.castShadow) {
          final shadow = light.shadow!;

          final shadowUniforms = shadowCache.get(light);

					shadowUniforms?['shadowIntensity'] = shadow.intensity;
          shadowUniforms?["shadowBias"] = shadow.bias;
          shadowUniforms?["shadowNormalBias"] = shadow.normalBias;
          shadowUniforms?["shadowRadius"] = shadow.radius;
          shadowUniforms?["shadowMapSize"] = shadow.mapSize;
          shadowUniforms?["shadowCameraNear"] = shadow.camera!.near;
          shadowUniforms?["shadowCameraFar"] = shadow.camera!.far;

          state.pointShadow.listSetter(pointLength, shadowUniforms);
          state.pointShadowMap.listSetter(pointLength, shadowMap);
          state.pointShadowMatrix.listSetter(pointLength, light.shadow!.matrix);

          numPointShadows++;
        }

        // state.point[ pointLength ] = uniforms;
        state.point.listSetter(pointLength, uniforms);

        pointLength++;
      } 
      else if (light is HemisphereLight) {
        final uniforms = cache.get(light);

        uniforms["skyColor"]..setFrom(light.color)..scale(intensity * scaleFactor);
        uniforms["groundColor"]..setFrom(light.groundColor)..scale(intensity * scaleFactor);

        // state.hemi[ hemiLength ] = uniforms;
        state.hemi.listSetter(hemiLength, uniforms);

        hemiLength++;
      } 
      else {
        throw (" WebGLLigts type: ${light.type} is not support ..... ");
      }
    }

    if (rectAreaLength > 0) {
      if ( extensions.has( 'OES_texture_float_linear' ) == true ) {
        state.rectAreaLTC1 = uniformsLib["LTC_FLOAT_1"];
        state.rectAreaLTC2 = uniformsLib["LTC_FLOAT_2"];
      }
      else{
        state.rectAreaLTC1 = uniformsLib["LTC_HALF_1"];
        state.rectAreaLTC2 = uniformsLib["LTC_HALF_2"];
      }
    }

    state.ambient[0] = r.toDouble();
    state.ambient[1] = g.toDouble();
    state.ambient[2] = b.toDouble();

    final hash = state.hash;

    if (hash["directionalLength"] != directionalLength ||
        hash["pointLength"] != pointLength ||
        hash["spotLength"] != spotLength ||
        hash["rectAreaLength"] != rectAreaLength ||
        hash["hemiLength"] != hemiLength ||
        hash["numDirectionalShadows"] != numDirectionalShadows ||
        hash["numPointShadows"] != numPointShadows ||
        hash["numSpotShadows"] != numSpotShadows ||
        hash['numSpotMaps'] != numSpotMaps ||
        hash['numLightProbes'] != numLightProbes ) {

      state.directional.length = directionalLength;
      state.spot.length = spotLength;
      state.rectArea.length = rectAreaLength;
      state.point.length = pointLength;
      state.hemi.length = hemiLength;

			state.directionalShadow.length = numDirectionalShadows;
			state.directionalShadowMap.length = numDirectionalShadows;
			state.pointShadow.length = numPointShadows;
			state.pointShadowMap.length = numPointShadows;
			state.spotShadow.length = numSpotShadows;
			state.spotShadowMap.length = numSpotShadows;
			state.directionalShadowMatrix.length = numDirectionalShadows;
			state.pointShadowMatrix.length = numPointShadows;
			state.spotLightMatrix.length = numSpotShadows + numSpotMaps - numSpotShadowsWithMaps;
			state.spotLightMap.length = numSpotMaps;
			state.numSpotLightShadowsWithMaps = numSpotShadowsWithMaps;
			state.numLightProbes = numLightProbes;

      hash["directionalLength"] = directionalLength;
      hash["pointLength"] = pointLength;
      hash["spotLength"] = spotLength;
      hash["rectAreaLength"] = rectAreaLength;
      hash["hemiLength"] = hemiLength;

      hash["numDirectionalShadows"] = numDirectionalShadows;
      hash["numPointShadows"] = numPointShadows;
      hash["numSpotShadows"] = numSpotShadows;

			hash['numSpotMaps'] = numSpotMaps;
			hash['numLightProbes'] = numLightProbes;

      state.version = nextVersion++;
    }
  }

  void setupView(List<Light> lights, Camera camera) {
    int directionalLength = 0;
    int pointLength = 0;
    int spotLength = 0;
    int rectAreaLength = 0;
    int hemiLength = 0;

    final viewMatrix = camera.matrixWorldInverse;

    for (int i = 0, l = lights.length; i < l; i++) {
      final light = lights[i];

      if (light is DirectionalLight) {
        final uniforms = state.directional[directionalLength];

        uniforms["direction"].setFromMatrixPosition(light.matrixWorld);
        vector3.setFromMatrixPosition(light.target!.matrixWorld);
        uniforms["direction"].sub(vector3);
        uniforms["direction"].transformDirection(viewMatrix);

        directionalLength++;
      } 
      else if (light is SpotLight) {
        final uniforms = state.spot[spotLength];

        uniforms["position"].setFromMatrixPosition(light.matrixWorld);
        uniforms["position"].applyMatrix4(viewMatrix);

        uniforms["direction"].setFromMatrixPosition(light.matrixWorld);
        vector3.setFromMatrixPosition(light.target!.matrixWorld);
        uniforms["direction"].sub(vector3);
        uniforms["direction"].transformDirection(viewMatrix);

        spotLength++;
      } 
      else if (light is RectAreaLight) {
        final uniforms = state.rectArea[rectAreaLength];

        uniforms["position"].setFromMatrixPosition(light.matrixWorld);
        uniforms["position"].applyMatrix4(viewMatrix);

        // extract local rotation of light to derive width/height half vectors
        matrix42.setFrom(Matrix4.identity());
        matrix4.setFrom(light.matrixWorld);
        matrix4.multiply(viewMatrix);
        matrix42.extractRotation(matrix4);

        uniforms["halfWidth"].setValues(light.width! * 0.5, 0.0, 0.0);
        uniforms["halfHeight"].setValues(0.0, light.height! * 0.5, 0.0);

        uniforms["halfWidth"].applyMatrix4(matrix42);
        uniforms["halfHeight"].applyMatrix4(matrix42);

        rectAreaLength++;
      } 
      else if (light is PointLight) {
        final uniforms = state.point[pointLength];
        
        (uniforms["position"] as Vector3).setFromMatrixPosition(light.matrixWorld);
        uniforms["position"].applyMatrix4(viewMatrix);

        pointLength++;
      } 
      else if (light is HemisphereLight) {
        final uniforms = state.hemi[hemiLength];

        uniforms["direction"].setFromMatrixPosition(light.matrixWorld);
        uniforms["direction"].transformDirection(viewMatrix);

        hemiLength++;
      }
    }
  }

  void dispose(){
    state.dispose();
    cache.dispose();
    shadowCache.dispose();
    extensions.dispose();
  }
}

class LightState {
  late num version;
  late Map<String, num> hash;
  late List<double> ambient;
  late List<Vector3> probe;
  late List directional;
  late List directionalShadow;
  late List directionalShadowMap;
  late List directionalShadowMatrix;
  late List spot;
  late List spotLightMap;
  late List spotShadow;
  late List spotShadowMap;
  late List spotShadowMatrix;
  late List spotLightMatrix;
  late List rectArea;
  late List point;
  late List pointShadow;
  late List pointShadowMap;
  late List pointShadowMatrix;
  late List hemi;
  late int numLightProbes;
  late int numSpotLightShadowsWithMaps;

  dynamic rectAreaLTC1;
  dynamic rectAreaLTC2;
  
  LightState(Map<String, dynamic> json) {
    version = json["version"];
    hash = json["hash"];
    ambient = List<double>.from(json["ambient"]);
    probe = List<Vector3>.from(json["probe"]);
    directional = json["directional"];
    directionalShadow = json["directionalShadow"];
    directionalShadowMap = json["directionalShadowMap"];
    directionalShadowMatrix = json["directionalShadowMatrix"];
    spot = json["spot"];
    spotLightMap = json['spotLightMap'];
    spotShadow = json["spotShadow"];
    spotShadowMap = json["spotShadowMap"];
    spotShadowMatrix = json["spotShadowMatrix"];
    spotLightMatrix = json["spotLightMatrix"];
    rectArea = json["rectArea"];
    point = json["point"];
    pointShadow = json["pointShadow"];
    pointShadowMap = json["pointShadowMap"];
    pointShadowMatrix = json["pointShadowMatrix"];
    hemi = json["hemi"];

    numSpotLightShadowsWithMaps = json['numSpotLightShadowsWithMaps'];
    numLightProbes = json['numLightProbes'];
  }

  void dispose(){
    hash.clear();
    ambient.clear();
    probe.clear();
    directional.clear();
    directionalShadow.clear();
    directionalShadowMap.clear();
    directionalShadowMatrix.clear();
    spot.clear();
    spotShadow.clear();
    spotShadowMap.clear();
    spotShadowMatrix.clear();
    rectArea.clear();
    point.clear();
    pointShadow.clear();
    pointShadowMap.clear();
    pointShadowMatrix.clear();
    hemi.clear();
  }
}