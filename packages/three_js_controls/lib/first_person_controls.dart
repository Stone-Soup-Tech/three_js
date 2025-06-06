import 'dart:math' as math;
import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:three_js_core/three_js_core.dart';
import 'package:three_js_math/three_js_math.dart';
import 'spherical.dart';
import 'package:flutter/material.dart' hide Matrix4;

enum LookType{active,position}

/// This class is an alternative implementation of [FlyControls].
class FirstPersonControls with EventDispatcher {

  /// [camera] - The camera to be controlled.
  /// 
  /// [listenableKey] - The element used for event listeners.
  FirstPersonControls({
    required this.camera,
    required this.listenableKey,
    this.lookType = LookType.active,
    this.movementSpeed = 1.0
  }):super(){
    domElement.addEventListener( PeripheralType.contextmenu, contextmenu, false );
    domElement.addEventListener( PeripheralType.pointerHover, onMouseMove, false );
    domElement.addEventListener( PeripheralType.pointerdown, onMouseDown, false );
    domElement.addEventListener( PeripheralType.pointerup, onMouseUp, false );
    //this.domElement.setAttribute( 'tabindex', - 1 );
    domElement.addEventListener( PeripheralType.keydown, onKeyDown, false );
    domElement.addEventListener( PeripheralType.keyup, onKeyUp, false );

    handleResize();
	  setOrientation(this);
  }

  late GlobalKey<PeripheralsState> listenableKey;
  PeripheralsState get domElement => listenableKey.currentState!;

	Camera camera;

	bool enabled = true;
  bool clickMove = false;

	double movementSpeed = 1.0;
  Vector3 velocity = Vector3();
	double lookSpeed = 0.05;

	bool lookVertical = true;
	bool autoForward = false;

	LookType lookType = LookType.active;

	bool heightSpeed = false;
	double heightCoef = 1.0;
	double heightMin = 0.0;
	double heightMax = 1.0;

	bool constrainVertical = false;
	double verticalMin = 0;
	double verticalMax = math.pi;

	// internals

	double autoSpeedFactor = 0.0;

	double mouseX = 0;
	double mouseY = 0;

	bool moveForward = false;
	bool moveBackward = false;
	bool moveLeft = false;
	bool moveRight = false;

  bool moveUp = false;
	bool moveDown = false;

	double viewHalfX = 0;
	double viewHalfY = 0;

	// private variables

	double lat = 0;
	double lon = 0;

	Vector3 lookDirection = Vector3();
	Spherical spherical = Spherical();
	Vector3 target = Vector3();
  Vector3 targetPosition = Vector3();

  /// Should be called if the application window is resized.
	void handleResize(){
		viewHalfX = domElement.clientWidth / 2;
		viewHalfY = domElement.clientHeight / 2;
	}

	void onMouseDown( event ) {
		if (clickMove) {
			switch ( event.button ) {
				case 0: moveForward = true; break;
				case 2: moveBackward = true; break;
			}
		}
	}

  bool get isMoving => moveBackward || moveDown || moveUp || moveForward || moveLeft || moveRight;

	void onMouseUp( event ) {
		if (clickMove) {
			switch ( event.button ) {
				case 0: moveForward = false; break;
				case 2: moveBackward = false; break;
			}
		}
	}

	void onMouseMove(event) {
    if(lookType == LookType.position){
      camera.rotation.y -= event.movementX*lookSpeed;
      camera.rotation.x -= event.movementY*lookSpeed;
    }
    else{
      mouseX = event.pageX - domElement.offsetLeft - viewHalfX;
      mouseY = event.pageY - domElement.offsetTop - viewHalfY;
    }
	}

	void onKeyDown(event) {
		switch ( event.keyId ) {
			case 4294968068: /*up*/
			case 119: /*W*/ 
        moveForward = true; 
        break;
			case 4294968066: /*left*/
			case 97: /*A*/ 
        moveLeft = true; 
        break;

			case 4294968065: /*down*/
			case 115: /*S*/ 
        moveBackward = true; 
        break;

			case 4294968067: /*right*/
			case 100: /*D*/ 
        moveRight = true; 
        break;

			case 114: /*R*/ 
        moveUp = true; 
        break;
			case 102: /*F*/ 
        moveDown = true; 
        break;
		}
	}

	void onKeyUp( event ) {
		switch ( event.keyId ) {
			case 4294968068: /*up*/
			case 119: /*W*/ 
        moveForward = false; 
        break;

			case 4294968066: /*left*/
			case 97: /*A*/ 
        moveLeft = false; 
        break;

			case 4294968065: /*down*/
			case 115: /*S*/ 
        moveBackward = false; 
        break;

			case 4294968067: /*right*/
			case 100: /*D*/ 
        moveRight = false; 
        break;

			case 114: /*R*/ 
        moveUp = false; 
        break;

			case 102: /*F*/ 
        moveDown = false; 
        break;
		}
	}

	FirstPersonControls lookAt (Vector3 v) {
		target.setFrom(v);
		camera.lookAt( target );
		setOrientation( this );
		return this;
	}
  Vector3 getForwardVector() {
    camera.getWorldDirection(targetPosition);
    targetPosition.y = 0;
    targetPosition.normalize();
    return targetPosition;
  }
  Vector3 getSideVector() {
    camera.getWorldDirection( targetPosition );
    targetPosition.y = 0;
    targetPosition.normalize();
    targetPosition.cross( camera.up );
    return targetPosition;
  }
  Vector3 getUpVector(){
    camera.getWorldDirection( targetPosition );
    targetPosition.x = 0;
    targetPosition.z = 0;
    targetPosition.y = 1;
    targetPosition.normalize();
    return targetPosition;
  }

  /// Updates the controls. Usually called in the animation loop.
  void update(double delta){
    if(enabled == false) return;

    if(heightSpeed) {
      double y = MathUtils.clamp<double>(camera.position.y, heightMin, heightMax );
      final heightDelta = y - heightMin;
      autoSpeedFactor = delta * (heightDelta * heightCoef);
    }
    else {
      autoSpeedFactor = 0.0;
    }

    double actualMoveSpeed = delta * movementSpeed;

    if(moveForward || ( autoForward && !moveBackward ) ){
      velocity.add( getForwardVector().scale(actualMoveSpeed));
    }
    if(moveBackward){
      velocity.add( getForwardVector().scale(-actualMoveSpeed));
    }
    if(moveLeft){
      velocity.add( getSideVector().scale(-actualMoveSpeed));
    }
    if(moveRight){
      velocity.add( getSideVector().scale(actualMoveSpeed));
    }
    if(moveUp){
      velocity.add( getUpVector().scale(actualMoveSpeed));
    }
    if(moveDown){
      velocity.add( getUpVector().scale(-actualMoveSpeed));
    }

    
    camera.position.setFrom(velocity);

    if (LookType.active == lookType ) {
      double actualLookSpeed = delta * lookSpeed*100;
      double verticalLookRatio = 1;

      if (constrainVertical ) {
        verticalLookRatio = math.pi / (verticalMax - verticalMin );
      }

      lon -= mouseX * actualLookSpeed;
      if (lookVertical ) lat -= mouseY * actualLookSpeed * verticalLookRatio;

      lat = math.max( - 85, math.min( 85, lat ) );

      double phi = ( 90 - lat ).toRad();
      num theta = lon.toRad();

      if (constrainVertical ) {
        phi = MathUtils.mapLinear( phi, 0, math.pi, verticalMin, verticalMax ).toDouble();
      }

      final position = camera.position;
      targetPosition.setFromSphericalCoords( 1, phi, theta ).add( position );
      camera.lookAt( targetPosition );
    }

  }

	void contextmenu( event ) {
		//event.preventDefault();
	}

  /// Should be called if the controls is no longer required.
	void deactivate() {
		domElement.removeEventListener( PeripheralType.contextmenu, contextmenu, false );
		domElement.removeEventListener( PeripheralType.pointerdown, onMouseDown, false );
	  domElement.removeEventListener( PeripheralType.pointerHover, onMouseMove, false );
		domElement.removeEventListener( PeripheralType.pointerup, onMouseUp, false );

		domElement.removeEventListener( PeripheralType.keydown, onKeyDown, false );
		domElement.removeEventListener( PeripheralType.keyup, onKeyUp, false );
  }

  void dispose(){
    clearListeners();
  }

	void setOrientation( controls ) {
		final quaternion = controls.camera.quaternion;

		lookDirection.setValues( 0, 0, - 1 ).applyQuaternion( quaternion );
		spherical.setFromVector3( lookDirection );

		lat = 90 - spherical.phi.toDeg();
		lon = spherical.theta.toDeg();
	}
}
