require 'spec_helper'

describe Isimud::Client do
  let(:client) { Isimud::Client.new }

  before do
    @exceptions_1 = Array.new
    @exceptions_2 = Array.new
  end

  describe 'exception handling' do
    let!(:exception_handler_1) { Proc.new { |e| @exceptions_1 << e } }
    let!(:exception_handler_2) { Proc.new { |e| @exceptions_2 << e } }
    let!(:exception) { double(:exception) }

    context 'with one handler added' do
      before do
        client.on_exception(&exception_handler_1)
        client.run_exception_handlers(exception)
      end

      it 'calls the exception handler' do
        expect(@exceptions_1).to include(exception)
      end
    end

    context 'with two handlers added' do
      before do
        client.on_exception(&exception_handler_1)
        client.on_exception(&exception_handler_2)
        client.run_exception_handlers(exception)
      end

      it 'calls both exception handlers' do
        expect(@exceptions_1).to include(exception)
        expect(@exceptions_2).to include(exception)
      end
    end
  end
end
