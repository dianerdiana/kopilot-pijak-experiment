import { Product as PrismaProduct } from '../../generated/prisma/client';

export const formatProduct = (product: PrismaProduct) => {
  return {
    id_produk: product.productId,
  };
};
