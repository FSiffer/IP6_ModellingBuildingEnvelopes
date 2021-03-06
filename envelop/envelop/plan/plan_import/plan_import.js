$(function() {
  // set up drag & drop
    $('body').on(
      'dragover',
      function(e) {
          e.preventDefault();
          e.stopPropagation();
      }
  )
  $('body').on(
      'dragenter',
      function(e) {
          e.preventDefault();
          e.stopPropagation();
      }
  )
  $('body').on(
      'drop',
      function(e){
          if(e.originalEvent.dataTransfer && e.originalEvent.dataTransfer.files.length) {
              e.preventDefault();
              e.stopPropagation();
               Array.from(e.originalEvent.dataTransfer.files).map(load_file);
          }
      }
  );

  // Upon click this should should trigger click on the #file-to-upload file input element
  // This is better than showing the not-good-looking file input element
  $("#upload-button").on('click', function() {
    $("#file-to-upload").trigger('click');
  });

  // When user chooses a PDF file
  $("#file-to-upload").on('change', function() {

    var ps = Array.from($("#file-to-upload").get(0).files).map(load_file);
    Promise.all(ps).then(call_save_imported_plans);
  });

  $(this).keydown(function(e) {
    if (e.key == 'a') {
      $("#file-to-upload").trigger('click');
    }
  });

  sketchup.call_load_imported_plans();
});

function load_file(f) {
  // if pdf
  if (f.type.includes('application/pdf')) {
    var pdf_url = URL.createObjectURL(f);

    return pdfjsLib.getDocument({
      url: pdf_url
    }).promise.then(load_pdf_doc).catch(function(error) {
      alert(error.message);
    });

  } else if (f.type.includes('image/')){
    return load_image_file(f);

  } else {
    window.alert("Plan Import can import pdf files and image files, however, you select a file of type '" + f.type + "'");
    return Promise.resolve(true);
  }
}

function load_image_file(image_file) {
  console.log("load_image_file");

  return new Promise((resolve, reject) => {
     var fr = new FileReader();
     fr.onload = () => {
        load_image_data(fr.result, resolve);
      };
     fr.readAsDataURL(image_file);
   });
}

function load_image_data(image_data, resolve) {
  console.log("load_image_data");

  var img = new Image();
  img.onload = () => {
      load_image_object(img, resolve);
  };
  img.src = image_data;
 }

function load_image_object(image_object,resolve) {
  console.log("load_image_object");

  var canvases = new_canvases();

  var image_width = image_object.width;
  var image_height = image_object.height;

  {
    var canvas_quality = canvases[1];

    canvas_quality.width = image_width / 4.0;
    canvas_quality.height = image_height / 4.0;

    var ctx = canvas_quality.getContext("2d");
    ctx.drawImage(image_object, 0, 0, image_width / 4.0, image_height / 4.0);
  }

  {
    var canvas = canvases[0];

    var width_bigger =  image_width > image_height;
    if (width_bigger) {
      scale = canvas.width / image_width;
      canvas.height = image_height * scale;
    } else {
      scale = canvas.height / image_height;
      canvas.width = image_width * scale;
    }

    ctx = canvas.getContext("2d");
    ctx.drawImage(image_object, 0, 0, image_width * scale, image_height * scale);
  }

  resolve(true);
}

function load_pdf_doc(pdf_doc) {
  // TODO: FS: consider fixing the previews so they have consisnten second border around prf preview

  var ps = [];

  for (i = 1; i <= pdf_doc.numPages; i++) {
    ps.push(pdf_doc.getPage(i).then(load_pdf_page));
  }

  return Promise.all(ps)
}

function load_pdf_page(page) {
  var canvases = new_canvases();
  var canvas = canvases[0];

  // find larger side, to determine scale
  var scale;
  var scale_one_object = {
    scale: 1
  };
  var viewport_width = page.getViewport(scale_one_object).width;
  var viewport_height = page.getViewport(scale_one_object).height;
  var width_bigger = viewport_width > viewport_height
  if (width_bigger) {
    scale = canvas.width / viewport_width;
  } else {
    scale = canvas.height / viewport_height;
  }

  var canvas_quality = canvases[1]; {
    viewport_quality = page.getViewport({scale: 2});
    canvas_quality.width = viewport_quality.width;
    canvas_quality.height = viewport_quality.height;
    p1 = page.render({
      canvasContext: canvas_quality.getContext('2d'),
      viewport: viewport_quality
    });
  }

  // Get viewport of the page at required scale
  var viewport = page.getViewport({
    scale: scale
  });
  canvas.width = viewport.width;
  canvas.height = viewport.height;

  // Render the page contents in the canvas
  p2 = page.render({
    canvasContext: canvas.getContext('2d'),
    viewport: viewport
  });

  return Promise.all([p1, p2]);
}


var $template;

function new_canvases() {
  if ($template === undefined) {
    $template = $("#plan-template");
  }

  var $clone = $template.clone();
  $clone.removeAttr('id');

  $clone.find('button').on('click', function() {
    $clone.remove();
    call_save_imported_plans();
  });

  $("#plan-container").append($clone);

  var canvases = $clone.find('canvas');

  $clone.on('click', function() {
    sketchup.import_image(canvases[1].toDataURL());
  });

  $clone.removeClass("hidden");

  return canvases
}

function call_save_imported_plans() {
  console.log("call_save_imported_plans");

  imageDataURLs = $("#plan-container").children().map(function(i, el) {
    original_quality = $(el).find(".original-quality")[0].toDataURL();
    preview_quality = $(el).find(".preview-quality")[0].toDataURL();
    return {
      original_quality: original_quality,
      preview_quality: preview_quality
    };
  }).get();
  sketchup.save_imported_plans(JSON.stringify(imageDataURLs));
}

function load_imported_plans(imported_plans) {
  imported_plans.forEach(imported_plan => {
    var canvases = new_canvases();

    var img = new window.Image();
    img.addEventListener("load", function() {
      canvases[0].width = img.width;
      canvases[0].height = img.height;
      canvases[0].getContext('2d').drawImage(img, 0, 0);
    });
    img.setAttribute("src", imported_plan.preview_quality);

    var img_quality = new window.Image();
    img_quality.addEventListener("load", function() {
      canvases[1].width = img_quality.width;
      canvases[1].height = img_quality.height;
      canvases[1].getContext('2d').drawImage(img_quality, 0, 0);
    });
    img_quality.setAttribute("src", imported_plan.original_quality);
  });
}
