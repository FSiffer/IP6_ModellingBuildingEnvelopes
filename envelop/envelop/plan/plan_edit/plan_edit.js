var cropper;

$(function() {
  $("#target")[0].addEventListener('ready', function() {
    setTimeout(function() {
      centerCropperCanvas();
      zoomCropperCanvas();
    }, 100);
  });

  cropper = new Cropper($("#target")[0], {
    viewMode: 0,
    //guides: false,
    //center: false,
    scalable: false,
    movable: true,
    zoomable: true,
    toggleDragModeOnDblclick: false, // prevent manual moving
    autoCrop: false, // start without a cropbox
  });

  mode_select = true;
  $("#switchMode").on('click', switch_mode);

  $("#rotCCW").on('click', function() {
    cropper.rotate(-90);
  });
  $("#rotCW").on('click', function() {
    cropper.rotate(90);
  });
  $('#place_F').on('click', function() {
    place($(this));
  });
  $('#place_N').on('click', function() {
    place($(this));
  });
  $('#place_W').on('click', function() {
    place($(this));
  });
  $('#place_S').on('click', function() {
    place($(this));
  });
  $('#place_E').on('click', function() {
    place($(this));
  });
  $("#cancel").on('click', function() {
    sketchup.cancel();
  });

  $(this).keydown(function(e) {
    // Key values: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values
    if (e.key == 'Escape') {
      sketchup.cancel();
    } else if (e.key == 'Shift' || e.key == 'Control' || e.key == 'Alt' || e.key == 'Meta') {
      switch_mode();
    } else if (e.key == 'ArrowLeft') {
        cropper.rotate(-90);
    } else if (e.key == 'ArrowRight') {
        cropper.rotate(90);
    } else if (e.key == 'f') {
      place($('#place_F'));
    } else if (e.key == 'n') {
      place($('#place_N'));
    } else if (e.key == 'e' || e.key == 'o') {
      place($('#place_E'));
    } else if (e.key == 's') {
      place($('#place_S'));
    } else if (e.key == 'w') {
      place($('#place_W'));
    }
  });

  $(window).on('resize', function(){
    cropper.clear(); // clear the cropbox
    centerCropperCanvas();
    zoomCropperCanvas();
  });

  sketchup.call_set_north();
  sketchup.call_set_image();
})

function switch_mode() {
  if (mode_select) {
    cropper.setDragMode("move");
    $("#switchLabel").html("Select Rectangle");
    mode_select = false;
  } else {
    cropper.setDragMode("crop");
    $("#switchLabel").html("Move Plan");
      mode_select = true;
  }
}

// zoom the cropper canvas to fit inside the container
function zoomCropperCanvas() {
  const containerData = cropper.getContainerData();
  const canvasData = cropper.getCanvasData();

  cropper.zoomTo(Math.min(
    containerData.height / canvasData.naturalHeight,
    containerData.width / canvasData.naturalWidth));
}

// move the cropper canvas to the center of the container
function centerCropperCanvas() {
  const containerData = cropper.getContainerData();
  const canvasData = cropper.getCanvasData();

  cropper.moveTo(
    (containerData.width / 2) - (canvasData.width / 2),
    (containerData.height / 2) - (canvasData.height / 2));
}

function place(button) {
  img = cropper.getCroppedCanvas().toDataURL();
  orientation = Number(button.val());

  $("#output").attr("src", img);
  $("#orientation").text(`orientation=${orientation}`);

  sketchup.accept(img, orientation);
}

function setImage(image_base64) {
  if (typeof cropper === 'undefined') return
  cropper.replace(image_base64);
}

function setNorth(north) {
  setCardinalDirectionText($("#place_N"), 90 - north);
  setCardinalDirectionText($("#place_W"), 180 - north);
  setCardinalDirectionText($("#place_S"), 270 - north);
  setCardinalDirectionText($("#place_E"), 360 - north);
}

function setCardinalDirectionText(element, direction /*angle in degrees*/) {
  direction += 1 // to get around rounding issues
  index = (Math.round(direction * (1 / 45)) / (1 / 45) / 45 % 8 + 8) % 8
  cardinal_directions = ['North', 'North-West', 'West', 'South-West', 'South', 'South-East', 'East', 'North-East']
  element.text(cardinal_directions[index])
}
