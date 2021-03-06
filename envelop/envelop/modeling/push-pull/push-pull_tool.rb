# frozen_string_literal: true

module Envelop
  module PushPullTool
    class PushPullTool < Envelop::ToolUtils::AbstractTool
      PHASES = { INITIAL: 0, FACE_SELECTED: 1 }.freeze

      def initialize
        super(PushPullTool, phases: PHASES,  cursor_id: Envelop::ToolUtils::CURSOR_PUSHPULL)
      end

      def enableVCB?
        @phase == PHASES[:FACE_SELECTED]
      end

      def draw(view)
        super(view)

        draw_preview(view) if @phase == PHASES[:FACE_SELECTED]
      end

      def onLButtonDown(flags, x, y, view)
        super(flags, x, y, view)

        if @phase == PHASES[:INITIAL]
          try_start_pushpull(view, x, y)
        else
          finish_pushpull
        end

        redraw
      end

      def onLButtonUp(flags, x, y, view)
        super(flags, x, y, view)

        if @dragged
          finish_pushpull
          redraw
        end
      end

      def onReturn(_view)
        if @phase != PHASES[:INITIAL]
          finish_pushpull
        end

        redraw
      end

      def onMouseMove(flags, x, y, view)
        super(flags, x, y, view)

        update_pushpull_vector(view, x, y) if @phase == PHASES[:FACE_SELECTED]
      end

      def set_status_text
        if @phase == PHASES[:FACE_SELECTED]
          Sketchup.status_text = 'Click/Release or `Enter` to accept preview, cyan adds, magenta removes. Input manual distance in the textfield. `Alt` to switch add mode. `Esc` to abort.'
          Sketchup.vcb_value = get_distance

        else
          Sketchup.status_text = 'Click/Drag a Face to push or pull. Double click a sloped Face to create a dormer. `Esc` to abort.'
          Sketchup.vcb_label = ''
        end
      end

      def onLButtonDoubleClick(_flags, x, y, view)
        face, transform = Envelop::GeometryUtils.pick_best_face(view, x, y)
        unless face.nil?
          # extrude the face to create a flat plateau in the x/y plane

          create_dormer(face, transform)
        end

        reset_tool
        redraw
      end

      private

      # inherited

      def reset_tool
        @face = nil
        @transform = nil
        @origin = nil
        @direction = nil
        @line = nil

        @pushpull_vector = Geom::Vector3d.new

        super
      end

      def populateExtents(boundingBox)
        if @phase == PHASES[:FACE_SELECTED]
          boundingBox.add(@face.vertices)
          boundingBox.add(@face.vertices.map { |v| @transform * v.position + @pushpull_vector })
        end
      end

      def onUserDistances(distances)
        # set the @pushpull_vector according to distance
        if @pushpull_vector.valid?
          @pushpull_vector.normalize!
        else
          @pushpull_vector = @direction
        end
        @pushpull_vector.length = distances[0]

        # finish operation
        finish_pushpull
      end

      # internal

      def create_dormer(face, transform)
        face_normal = Envelop::GeometryUtils.normal_transformation(transform) * face.normal
        z_coords = face.vertices.map { |v| (transform * v.position).z }
        max_z = z_coords.max
        min_z = z_coords.min

        successful = Envelop::OperationUtils.operation_chain 'Add Lukarne', false, lambda {
          # only continue if face is sloped
          !face_normal.parallel?(Z_AXIS) && !face_normal.perpendicular?(Z_AXIS)
        }, lambda  {
          group = Envelop::GeometryUtils.pushpull_face(face, transform: transform) do |p|
            Geom::Point3d.new(p.x, p.y, face_normal.dot(Z_AXIS) > 0 ? max_z : min_z)
          end

          # add the group to the house
          Envelop::Housekeeper.add_to_house(group)
        }, lambda {
          # check if house is still manifold
          Envelop::Housekeeper.get_or_find_house&.manifold? || false
        }, lambda  {
          Envelop::Materialisation.apply_default_material
          Envelop::GeometryUtils.erase_face(@face) unless @face.deleted?
          true
        }

        unless successful
          # inform user of failure
          UI.messagebox('Unable to create dormer because the result would be invalid')
        end
      end

      def update_pushpull_vector(view, x, y)
        if @ip.edge.nil? && @ip.vertex.nil? && !Envelop::GeometryUtils.is_image_face(@ip.face)
          camera_ray = view.pickray(x, y)
          target = Geom.closest_points(@line, camera_ray)[0]
        else
          target = @ip.position.project_to_line(@line)
        end

        @pushpull_vector = target - @origin
      end

      def try_start_pushpull(view, x, y)
        @face, @transform = Envelop::GeometryUtils.pick_best_face(view, x, y)

        if !@face.nil?
          @origin = @transform * @face.bounds.center
          @direction = Envelop::GeometryUtils.normal_transformation(@transform) * @face.normal
          @line = [@origin, @direction]
          @phase = PHASES[:FACE_SELECTED]

        else
          @face = nil
          @transform = nil
        end
      end

      def draw_preview(view)
        color = to_add? ? 'Cyan' : 'Magenta'

        # draw new face
        @face.loops.each do |loop|
          points = loop.vertices.map { |v| @transform * v.position + @pushpull_vector }
          points << points[0]
          Envelop::GeometryUtils.draw_lines(view, color, *points)
        end

        # draw connections to old face
        @face.outer_loop.vertices.each do |v|
          Envelop::GeometryUtils.draw_lines(view, color, @transform * v.position, @transform * v.position + @pushpull_vector)
        end
      end

      def pushpull_group
        if !@pushpull_vector.valid?
          nil
        else
          Envelop::GeometryUtils.pushpull_face(@face, transform: @transform) { |p| p + @pushpull_vector }
        end
      end

      def to_add?
        res = true

        Envelop::ToolUtils.silenced do
          Envelop::OperationUtils.operation_chain('Internal Preview Operation', false, lambda  {
            group = pushpull_group
            return false if group.nil?

            group_volume = group.volume

            house = Envelop::Housekeeper.get_house()
            return false if house.nil?

            intersection = house.intersect(group)

            res = (intersection.nil? || (group_volume - intersection.volume).abs >= 0.001)
            return false
           })
        end
        if @alternate_mode
          not res
        else
          res
        end
      end

      def finish_pushpull
        to_add = to_add?

        successful = Envelop::OperationUtils.operation_chain("Push/Pull #{to_add ? 'Add' : 'Subtract'}", false, lambda {
          group = pushpull_group

          return false if group.nil?

          # Add newly created group to house
          if to_add
            Envelop::Housekeeper.add_to_house(group)
          else
            Envelop::Housekeeper.remove_from_house(group)
          end
        }, lambda {
          # check if house is still manifold
          Envelop::Housekeeper.get_or_find_house&.manifold? || false
        }, lambda {
          Envelop::Materialisation.apply_default_material

          # delete original face
          Envelop::GeometryUtils.erase_face(@face) unless @face.deleted?

          # return true to commit operation
          true
        })

        reset_tool

        unless successful
          # inform user of failure
          UI.messagebox('Unable to Push-Pull because the result would be invalid')
        end
      end

      def get_distance
        if @pushpull_vector.valid?
          distance = @pushpull_vector.length
        else
          distance = 0
        end
        distance.to_l.to_s
      end
    end

    #
    # Activate the custom Push-Pull Tool
    #
    # @param add [Boolean] whether the created volume should be added (true) or subtracted (false) from the house
    #
    def self.activate_pushpull_tool(_add = true)
      Sketchup.active_model.select_tool(Envelop::PushPullTool::PushPullTool.new)
    end

    def self.reload
      Sketchup.active_model.select_tool(nil)
    end
    reload
  end
end
