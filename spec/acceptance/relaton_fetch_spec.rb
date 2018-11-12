require "spec_helper"

RSpec.describe "Relaton Fetch" do
  describe "relaton fetch" do
    context "fetch code with a type" do
      it "prints out the document for valid code and type" do
        output = command("relaton fetch --type ISO 'ISO 2146'")

        expect(output.stdout).to include('<relation type="obsoletes">')
        expect(output.stdout).to include('<docidentifier type="ISO">ISO 2146')
      end
    end

    context "fetch code with date specified" do
      it "prints out the correct document for valid date" do
        output = command("relaton fetch -t ISO -y 2010 'ISO 2146'")

        expect(output.stdout).to include('<relation type="obsoletes">')
        expect(output.stdout).to include('<docidentifier type="ISO">ISO 2146')
      end

      it "prints out a warning messages for wrong date" do
        output = command("relaton fetch -t ISO -y 2009 'ISO 2146'")
        expect(output.stdout).to include("No matching bibliographic entry")
      end
    end

    context "fetch code with invalid/missing type" do
      it "prints a warning message for missing --type option" do
        output = command("relaton fetch 'ISO 2146'")
        expect(output.stderr).to include("required options '--type'")
      end

      it "prints a warning message with suggestions for invalid type" do
        output = command("relaton fetch 'ISO 2146' --type invalid")
        expect(output.stdout).to include("Recognised types: CN, IEC, IETF, ISO")
      end
    end

    context "fetch code with undefined standard" do
      it "prints out a warning message for undefined standard" do
        output = command("relaton fetch -t ISO 'ISO ABCDEFGH'")
        expect(output.stdout).to include("No matching bibliographic entry foun")
      end
    end
  end
end
