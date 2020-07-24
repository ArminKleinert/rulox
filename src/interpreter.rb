require_relative "./runtimeError"
require_relative "./logger"
require_relative "./environment"

class Interpreter
	@environment = Environment.new

	def self.interpret statements
		begin
			statements.each do |stmt|
				execute stmt
			end
		rescue LoxRuntimeError => error
			Logger.runtime_error error
		end
	end

	def self.visitWhileStmt stmt
		execute stmt.body while truthy? evaluate stmt.condition
	end

	def self.visitRubyExpr expr
		eval (evaluate expr.code).to_s
	end

	def self.visitLogicalExpr expr
		left = evaluate expr.left

		if operator.type == :OR
			return left if truthy? left
		
		# AND
		else
			return left if !truthy? left
		end

		return evaluate expr.right
	end

	def self.visitIfStmt stmt
		if truthy? evaluate stmt.condition
			execute stmt.thenBranch
		elsif stmt.elseBranch
			execute stmt.elseBranch
		end
	end

	def self.visitTernaryExpr expr
		if truthy? evaluate expr.condition
			return evaluate expr.first
		else
			return evaluate expr.second
		end
	end

	def self.visitBlockStmt stmt
		executeBlock stmt.statements
	end

	def self.visitAssignmentExpr expr
		value = evaluate expr.expression

		@environment.assign expr.name, value
	end

	def self.visitVariableExpr expr
		@environment.get expr.name
	end

	def self.visitVarDeclStmt stmt
		value = nil
		value = evaluate stmt.initializer if stmt.initializer

		@environment.define stmt.name, value
	end

	def self.visitExpressionStmt stmt
		evaluate stmt.expression
	end

	def self.visitPrintStmt stmt
		value = evaluate stmt.expression
		if value.class == NilClass
			puts "nil" 
		else
			puts evaluate stmt.expression
		end
	end

	def self.evaluate expr
		expr.accept self
	end

	def self.execute stmt
		stmt.accept self
	end

	def self.truthy? var
		var != nil && var.class != FalseClass
	end

	def self.equal? first, second
		#Simply inherit Ruby's system
		first.equal? second
	end

	def self.visitBinaryExpr expr
		operator = expr.operator
		left = evaluate expr.left
		right = evaluate expr.right

		case operator.type
			when :MINUS, :MINUS_EQUAL
				Checker.number operator, left, right
				left - right
			when :SLASH
				Checker.number operator, left, right

				# Don't divide by zero
				if right == 0
					raise LoxRuntimeError.new operator, "Dividing by zero is not allowed"
				end

				left / right
			when :ASTERISk
				Checker.number operator, left, right
				left * right
			when :PLUS, :PLUS_EQUAL
				Checker.number_or_string operator, left, right
				
				if left.class == String && right.class == Integer
					return left + right.to_s
				end
				
				if left.class == Integer && right.class == String
					raise LoxRuntimeError.new operator, "Cannot add string to integer"
				end

				left + right

			#comparison
			when :GREATER
				Checker.number operator, left, right
				left > right
			when :GREATER_EQUAL
				Checker.number operator, left, right
				left >= right
			when :LESS
				Checker.number operator, left, right
				left < right
			when :LESS_EQUAL
				Checker.number operator, left, right
				left <= right
			when :BANG_EQUAL
				equal? left, right
			when :EQUAL_EQUAL
				equal? left, right
		end

	end

	def self.visitGroupingExpr expr
		evaluate expr.expression
	end

	def self.visitLiteralExpr expr
		expr.value
	end

	def self.visitUnaryExpr expr
		right = evaluate expr.right

		case operator.type
			when :MINUS
				Checker.number operator, right
				-right
			when :BANG
				!truthy? right
		end

	end

	def self.executeBlock statements
		previous_environment = @environment
		@environment = Environment.new @environment

		statements.each do |stmt|
			stmt.accept self
		end

		# discard current env and use previous
		@environment = previous_environment

	end

end

class Checker

	def self.number operator, *operands
		raise LoxRuntimeError.new operator, "Operands must be a number" if !operands.all? {|op| op.class == Integer}
	end

	def self.number_or_string operator, *operands
		raise LoxRuntimeError.new operator, "Operands must be a number or string" if !operands.all? {|op| op.class == Integer || op.class == String}
	end

end
