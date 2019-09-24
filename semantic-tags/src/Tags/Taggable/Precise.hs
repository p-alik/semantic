{-# LANGUAGE AllowAmbiguousTypes, ConstraintKinds, FlexibleContexts, FlexibleInstances, MultiParamTypeClasses, RankNTypes, ScopedTypeVariables, TypeApplications, TypeOperators #-}
module Tags.Taggable.Precise
( runTagging
, Tags
, ToTags(..)
, yield
, GFold1(..)
) where

import Control.Effect.Reader
import Control.Effect.Writer
import Data.Monoid (Endo(..))
import GHC.Generics
import Source.Loc
import Source.Source
import Tags.Tag

runTagging :: ToTags t => Source -> t Loc -> [Tag]
runTagging source
  = ($ [])
  . appEndo
  . run
  . execWriter
  . runReader source
  . tags

type Tags = Endo [Tag]

class ToTags t where
  tags
    :: ( Carrier sig m
       , Member (Reader Source) sig
       , Member (Writer Tags) sig
       )
    => t Loc
    -> m ()


yield :: (Carrier sig m, Member (Writer Tags) sig) => Tag -> m ()
yield = tell . Endo . (:)


class GFold1 c t where
  gfold1
    :: Monoid b
    => (forall f . c f => f a -> b)
    -> t a
    -> b

instance GFold1 c f => GFold1 c (M1 i c' f) where
  gfold1 alg = gfold1 @c alg . unM1

instance (GFold1 c f, GFold1 c g) => GFold1 c (f :*: g) where
  gfold1 alg (f :*: g) = gfold1 @c alg f <> gfold1 @c alg g

instance (GFold1 c f, GFold1 c g) => GFold1 c (f :+: g) where
  gfold1 alg (L1 l) = gfold1 @c alg l
  gfold1 alg (R1 r) = gfold1 @c alg r

instance GFold1 c (K1 R t) where
  gfold1 _ _ = mempty

instance GFold1 c Par1 where
  gfold1 _ _ = mempty

instance c t => GFold1 c (Rec1 t) where
  gfold1 alg (Rec1 t) = alg t

instance (Foldable f, GFold1 c g) => GFold1 c (f :.: g) where
  gfold1 alg = foldMap (gfold1 @c alg) . unComp1

instance GFold1 c U1 where
  gfold1 _ _ = mempty
