#!/usr/bin/env bash

# Global equality operator (`==`): returns a bool. Comparison binds tighter
# than the boolean connectives (or 1 < and 2 < comparison 3).
@operation.condition.eq() {
  @infix 3
  @symbol '=='
  @in.string left
  @in.string right
  @out.bool result

  @do() {
    left=$(@in left)
    right=$(@in right)

    if [ "$left" = "$right" ]; then
      @out.bool result true
    else
      @out.bool result false
    fi

    @return.out
  }
}
