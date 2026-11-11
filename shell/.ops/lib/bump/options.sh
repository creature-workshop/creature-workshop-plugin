#!/bin/sh

:<<'FRAGMENT'
The options struct ops git-bump hands bump__plan_bump, read as the questions a plan
asks of it: which release level the flags name, which prerelease channel they
name, whether a release was asked for at all, and whether the run is releasing
the prerelease it starts from.

An absent field reads as the answer "no flag said so", so a flagless run falls
through every one of these to the auto bump.
FRAGMENT

__bump__is_release_bump() {
  @succeeds __bump__is_release_bump__out @defined "$(__bump__release_type "$1")"
  println "$__bump__is_release_bump__out"
}

__bump__is_prerelease_bump() {
  @succeeds __bump__is_prerelease_bump__out @defined "$(__bump__prerelease_type "$1")"
  println "$__bump__is_prerelease_bump__out"
}

__bump__is_releasing_prerelease() {
  __bump__is_releasing_prerelease__version="$1"
  __bump__is_releasing_prerelease__options="$2"

  @get __bump__is_releasing_prerelease__pre_type "$__bump__is_releasing_prerelease__version" '.pre_type' ''
  __bump__is_releasing_prerelease__release_requested="$(__bump__release_requested "$__bump__is_releasing_prerelease__options")"
  if @defined "$__bump__is_releasing_prerelease__pre_type" && @is_true "$__bump__is_releasing_prerelease__release_requested"; then
    @true __bump__is_releasing_prerelease__out
    println "$__bump__is_releasing_prerelease__out"
  else
    @false __bump__is_releasing_prerelease__out
    println "$__bump__is_releasing_prerelease__out"
  fi
}

__bump__release_type() {
  @get __bump__release_type__out "$1" '.release_type' ''
  println "$__bump__release_type__out"
}

__bump__prerelease_type() {
  @get __bump__prerelease_type__out "$1" '.prerelease_type' ''
  println "$__bump__prerelease_type__out"
}

__bump__release_requested() {
  @get __bump__release_requested__out "$1" '.release' 'false'
  println "$__bump__release_requested__out"
}
