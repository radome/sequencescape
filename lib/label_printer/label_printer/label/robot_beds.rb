
module LabelPrinter
  module Label

    class RobotBeds < BasePlate

      attr_reader :plates

      def initialize(beds)
        @plates = beds
      end

      def top_right(bed)
        "Bed #{bed.barcode}"
      end

      def bottom_right(bed)
        "#{bed.ean13_barcode}"
      end

      def far_bottom_right(bed)
        "#{bed.robot.barcode}"
      end

    end
  end
end
