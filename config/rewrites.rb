# encoding: utf-8
class RewriteConfig
  def self.list
    [{
      method: :r301,
      from: /(.*)/,
      to: 'https://www.fairnopoly.de/categories/bucher',
      if: /b(ü|u|ue)cher\./i
    },{
      method: :r301,
      from: /(.*)/,
      to: 'https://www.fairnopoly.de/categories/weitere-abf793c9-d94b-423c-947d-0d8cb7bbe3b9',
      if: /weitere\./i
    },{
      method: :r301,
      from: /(:\/\/www\.)(fairmondo)(.*)/i,
      to: 'https://www.fairnopoly$3',
      if:  /(.*)/
    }]
  end
end

module Rack
  class Rewrite
    class FairnopolyRuleSet
      attr_reader :rules

      def initialize(options)
        @rules = RewriteConfig.list.map do |rule|
          Rule.new(rule[:method], rule[:from], rule[:to], {if: Proc.new do |rack_env|
            rack_env['SERVER_NAME'] =~ rule[:if]
          end})
        end
      end
    end
  end
end
