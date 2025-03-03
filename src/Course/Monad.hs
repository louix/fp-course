{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE RebindableSyntax #-}

module Course.Monad where

import Course.Applicative
import Course.Core
import Course.ExactlyOne
import Course.Functor
import Course.List
import Course.Optional
import qualified Prelude as P((=<<))

-- | All instances of the `Monad` type-class must satisfy one law. This law
-- is not checked by the compiler. This law is given as:
--
-- * The law of associativity
--   `∀f g x. g =<< (f =<< x) ≅ ((g =<<) . f) =<< x`
class Applicative k => Monad k where
  -- Pronounced, bind.
  (=<<) ::
    (a -> k b)
    -> k a
    -> k b

infixr 1 =<<

-- | Binds a function on the ExactlyOne monad.
--
-- >>> (\x -> ExactlyOne(x+1)) =<< ExactlyOne 2
-- ExactlyOne 3
instance Monad ExactlyOne where
  (=<<) ::
    (a -> ExactlyOne b)
    -> ExactlyOne a
    -> ExactlyOne b
  (=<<) fk (ExactlyOne a) = fk a

-- | Binds a function on a List.
--
-- >>> (\n -> n :. n :. Nil) =<< (1 :. 2 :. 3 :. Nil)
-- [1,1,2,2,3,3]
instance Monad List where
  (=<<) ::
    (a -> List b)
    -> List a
    -> List b
  (=<<) = flatMap

-- | Binds a function on an Optional.
--
-- >>> (\n -> Full (n + n)) =<< Full 7
-- Full 14
instance Monad Optional where
  (=<<) ::
    (a -> Optional b)
    -> Optional a
    -> Optional b
  (=<<) fk (Full a) = fk a
  (=<<) _ Empty = Empty

-- | Binds a function on the reader ((->) t).
--
-- >>> ((*) =<< (+10)) 7
-- 119
instance Monad ((->) t) where
  (=<<) ::
    (a -> ((->) t b))
    -> ((->) t a)
    -> ((->) t b)
  (=<<) fa fb a = fa (fb a) a
-- Intuition:
-- for: ((*) =<< (+10)) 7
-- we need to apply 7 to both arguments, then apply them together
-- (*7) =<< 17
-- 7 * 17
-- 119


-- | Witness that all things with (=<<) and (<$>) also have (<*>).
--
-- >>> ExactlyOne (+10) <**> ExactlyOne 8
-- ExactlyOne 18
--
-- >>> (+1) :. (*2) :. Nil <**> 1 :. 2 :. 3 :. Nil
-- [2,3,4,2,4,6]
--
-- >>> Full (+8) <**> Full 7
-- Full 15
--
-- >>> Empty <**> Full 7
-- Empty
--
-- >>> Full (+8) <**> Empty
-- Empty
--
-- >>> ((+) <**> (+10)) 3
-- 16
--
-- >>> ((+) <**> (+5)) 3
-- 11
--
-- >>> ((+) <**> (+5)) 1
-- 7
--
-- >>> ((*) <**> (+10)) 3
-- 39
--
-- >>> ((*) <**> (+2)) 3
-- 15
(<**>) ::
  Monad k =>
  k (a -> b)
  -> k a
  -> k b
(<**>) kf ka = (<$> ka) =<< kf
-- Intuition:
-- easier to read: (\x -> x <$> ka) =<< kf

infixl 4 <**>

-- | Flattens a combined structure to a single structure.
--
-- >>> join ((1 :. 2 :. 3 :. Nil) :. (1 :. 2 :. Nil) :. Nil)
-- [1,2,3,1,2]
--
-- >>> join (Full Empty)
-- Empty
--
-- >>> join (Full (Full 7))
-- Full 7
--
-- >>> join (+) 7
-- 14
join ::
  Monad k =>
  k (k a)
  -> k a
join kka = id =<< kka
-- Intuition:
-- basically flatMap in the case of arrays (but different per monad)
-- (id =<< kka) gets you the implementation without any side effects

-- | Implement a flipped version of @(=<<)@, however, use only
-- @join@ and @(<$>)@.
-- Pronounced, bind flipped.
--
-- >>> ((+10) >>= (*)) 7
-- 119
(>>=) ::
  Monad k =>
  k a
  -> (a -> k b)
  -> k b
(>>=) ka fk = join (fk <$> ka)
-- Intuition:
-- Says use fmap (<$>) and join
-- need to fmap ka to fk
-- join is left

infixl 1 >>=

-- | Implement composition within the @Monad@ environment.
-- Pronounced, Kleisli composition.
--
-- >>> ((\n -> n :. n :. Nil) <=< (\n -> n+1 :. n+2 :. Nil)) 1
-- [2,2,3,3]
(<=<) ::
  Monad k =>
  (b -> k c)
  -> (a -> k b)
  -> a
  -> k c
(<=<) fa fb a = fa =<< fb a
-- Intuition:
-- (\n -> n :. n :. Nil) =<< (1 :. 2 :. Nil)
-- (\n -> n :. n :. Nil) <=< (\n -> n+1 :. n+2 :. Nil) 1

infixr 1 <=<

-----------------------
-- SUPPORT LIBRARIES --
-----------------------

instance Monad IO where
  (=<<) =
    (P.=<<)
