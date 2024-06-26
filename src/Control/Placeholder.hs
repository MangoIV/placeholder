{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE MagicHash #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE CPP #-}

#if __GLASGOW_HASKELL__ >= 980
#define WARNING_IN_XTODO WARNING in "x-todo"
#else
#define WARNING_IN_XTODO WARNING
#endif

{- | The 'Control.Placeholder' module implements various functions to indicate 
     unfinished or generally unimplemented code 
-}
module Control.Placeholder
  (
  -- * Combinators
    todo
  , unimplemented
  -- * Patterns
  , pattern TODO
  , pattern Unimplemented
  -- * IO
  , todoIO
  , unimplementedIO
  -- * Exceptions
  , TodoException(TodoException, TodoExceptionWithLocation)
  , UnimplementedException(UnimplementedException, UnimplementedExceptionWithLocation)
  ) where

import Control.Exception
import Data.List (intercalate)
import Data.Typeable
import GHC.Base (raise#, raiseIO#, TYPE, RuntimeRep)
import GHC.Exception
import GHC.Stack
import GHC.Types (IO(IO))
import System.IO.Unsafe

-- | This is the 'Exception' thrown by 'todo', 'TODO' and 'todoIO'.
data TodoException = TodoExceptionWithLocation String
  deriving (Typeable, Exception)

instance Show TodoException where
  showsPrec _ (TodoExceptionWithLocation loc)
    = showString todoMessage . showChar '\n' . showString loc

-- | This lets us discard the location information in a TodoException
pattern TodoException :: TodoException
pattern TodoException <- TodoExceptionWithLocation _ where
  TodoException = TodoExceptionWithLocation missingLocation

-- | This is the 'Exception' thrown by 'unimplemented', 'Unimplemented', and 'unimplementedIO'.
data UnimplementedException = UnimplementedExceptionWithLocation String
  deriving (Typeable, Exception)

instance Show UnimplementedException where
  showsPrec _ (UnimplementedExceptionWithLocation loc)
    = showString unimplementedMessage . showChar '\n' . showString loc

pattern UnimplementedException :: UnimplementedException
pattern UnimplementedException <- UnimplementedExceptionWithLocation _ where
  UnimplementedException = UnimplementedExceptionWithLocation missingLocation

-- | robust retrieval of the current callstack suitable for custom exception types
withCallStack :: Exception a => (String -> a) -> CallStack -> SomeException
withCallStack f stk = unsafeDupablePerformIO $ do
  ccsStack <- currentCallStack
  let
    implicitParamCallStack = prettyCallStackLines stk
    ccsCallStack = showCCSStack ccsStack
    stack = intercalate "\n" $ implicitParamCallStack ++ ccsCallStack
  pure $ toException (f stack)

{- | 'todo' indicates unfinished code.

It is to be used whenever you want to indicate that you are missing a part of
the implementation and want to fill that in later.

The main difference to other alternatives like typed holes and 'undefined'
or 'error' is, this does not throw an error but only emits a warning.

Similarly to 'undefined', 'error' and typed holes, this will throw an error if
it is evaluated at runtime which can only be caught in 'IO'.

This is intended to *never* stay in code but exists purely for signifying
"work in progress" code.

To make the emitted warning error instead (e.g. for the use in CI), add
the @-Werror=x-todo@ flag to your @OPTIONS_GHC@.

==== __Examples__

@
superComplexFunction :: 'Maybe' a -> 'IO' 'Int'
-- we already know how to implement this in the 'Nothing' case
superComplexFunction 'Nothing' = 'pure' 42
-- but the 'Just' case is super complicated, so we leave it as 'todo' for now
superComplexFunction ('Just' a) = 'todo'
@
-}
todo :: forall {r :: RuntimeRep} (a :: TYPE r). HasCallStack => a
todo = raise# (withCallStack TodoExceptionWithLocation ?callStack)
{-# WARNING_IN_XTODO todo "'todo' left in code" #-}

{- | 'todoIO' indicates unfinished code that lives in the IO monad.

It should be used similarly to how 'throwIO' should be used rather than 'throw' in IO
to throw at the time the IO action is run rather than at the time it is created.

-}
todoIO :: HasCallStack => IO a
todoIO = IO (raiseIO# (withCallStack TodoExceptionWithLocation ?callStack))
{-# WARNING_IN_XTODO todoIO "'todoIO' left in code" #-}

{- | 'TODO' indicates unfinished code or an unfinished pattern match

You can use this in most positions where you could pass 'todo', but it also can be used in pattern position
to indicate that there are cases you haven't considered.

There remain some circumstances where you can only use 'todo', however, they arise when using this in a "PolyKinded" situation.

-}
pattern TODO :: HasCallStack => () => a
pattern TODO <- (raise# (withCallStack TodoExceptionWithLocation ?callStack) -> _unused) where
  TODO = raise# (withCallStack TodoExceptionWithLocation ?callStack)
{-# WARNING_IN_XTODO TODO "'TODO' left in code" #-}
{-# COMPLETE TODO #-}

{- | 'unimplemented' indicates that the relevant code is unimplemented. Unlike 'todo', it is expected that this _may_ remain in code
long term, and so no warning is supplied. Use cases might include places where a typeclass would theoretically require a member to be
implemented, but where the resulting violation is actually intended.
-}

unimplemented :: forall {r :: RuntimeRep} (a :: TYPE r). HasCallStack => a
unimplemented = raise# (withCallStack UnimplementedExceptionWithLocation ?callStack)

{- | 'unimplementedIO' indicates that the method is unimplemented, but it lives in IO, and so only throws when actually run, rather
than when it is constructed. Unlike 'todoIO' it does not provide a compile-time warning, as it is expected that this _may_ remain in
code long term.

-}

unimplementedIO :: HasCallStack => IO a
unimplementedIO = IO (raiseIO# (withCallStack UnimplementedExceptionWithLocation ?callStack))

{- | 'Unimplemented' can be used in most circumstances 'unimplemented' can, but it can also be used in pattern position to indicate cases
haven't been considered yet. Unlike 'TODO' it does not provide a compile-time warning, as it is expected that this _may_ remain in code long term.

-}
pattern Unimplemented :: HasCallStack => () => a
pattern Unimplemented <- (raise# (withCallStack UnimplementedExceptionWithLocation ?callStack) -> _unused) where
  Unimplemented = raise# (withCallStack UnimplementedExceptionWithLocation ?callStack)
{-# COMPLETE Unimplemented #-}

missingLocation :: String
missingLocation = ""
{-# NOINLINE missingLocation #-}

todoMessage :: String
todoMessage = "Control.Placeholder.todo: not yet implemented"
{-# NOINLINE todoMessage #-}

unimplementedMessage :: String
unimplementedMessage = "Control.Placeholder.unimplemented: unimplemented"
{-# NOINLINE unimplementedMessage #-}

