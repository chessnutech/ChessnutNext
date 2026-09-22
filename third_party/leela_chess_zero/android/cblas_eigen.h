// CBLAS interface implemented using Eigen
// This provides the CBLAS functions needed by lc0's BLAS backend on Android

#ifndef CBLAS_EIGEN_H
#define CBLAS_EIGEN_H

#include <Eigen/Dense>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum CBLAS_ORDER { CblasRowMajor = 101, CblasColMajor = 102 } CBLAS_ORDER;
typedef enum CBLAS_TRANSPOSE {
  CblasNoTrans = 111,
  CblasTrans = 112,
  CblasConjTrans = 113
} CBLAS_TRANSPOSE;

// SGEMM: Single-precision General Matrix Multiply
// C = alpha * op(A) * op(B) + beta * C
inline void cblas_sgemm(CBLAS_ORDER order, CBLAS_TRANSPOSE transA,
                        CBLAS_TRANSPOSE transB, int M, int N, int K,
                        float alpha, const float* A, int lda, const float* B,
                        int ldb, float beta, float* C, int ldc) {
  using namespace Eigen;

  if (order == CblasRowMajor) {
    // Row-major: A is M x K, B is K x N, C is M x N
    Map<const Matrix<float, Dynamic, Dynamic, RowMajor>> matA(
        A, (transA == CblasNoTrans) ? M : K, (transA == CblasNoTrans) ? K : M);
    Map<const Matrix<float, Dynamic, Dynamic, RowMajor>> matB(
        B, (transB == CblasNoTrans) ? K : N, (transB == CblasNoTrans) ? N : K);
    Map<Matrix<float, Dynamic, Dynamic, RowMajor>> matC(C, M, N);

    if (transA == CblasNoTrans && transB == CblasNoTrans) {
      matC = alpha * matA * matB + beta * matC;
    } else if (transA == CblasTrans && transB == CblasNoTrans) {
      matC = alpha * matA.transpose() * matB + beta * matC;
    } else if (transA == CblasNoTrans && transB == CblasTrans) {
      matC = alpha * matA * matB.transpose() + beta * matC;
    } else {
      matC = alpha * matA.transpose() * matB.transpose() + beta * matC;
    }
  } else {
    // Column-major
    Map<const Matrix<float, Dynamic, Dynamic, ColMajor>> matA(
        A, (transA == CblasNoTrans) ? M : K, (transA == CblasNoTrans) ? K : M);
    Map<const Matrix<float, Dynamic, Dynamic, ColMajor>> matB(
        B, (transB == CblasNoTrans) ? K : N, (transB == CblasNoTrans) ? N : K);
    Map<Matrix<float, Dynamic, Dynamic, ColMajor>> matC(C, M, N);

    if (transA == CblasNoTrans && transB == CblasNoTrans) {
      matC = alpha * matA * matB + beta * matC;
    } else if (transA == CblasTrans && transB == CblasNoTrans) {
      matC = alpha * matA.transpose() * matB + beta * matC;
    } else if (transA == CblasNoTrans && transB == CblasTrans) {
      matC = alpha * matA * matB.transpose() + beta * matC;
    } else {
      matC = alpha * matA.transpose() * matB.transpose() + beta * matC;
    }
  }
}

// SGEMV: Single-precision General Matrix-Vector multiply
// y = alpha * op(A) * x + beta * y
inline void cblas_sgemv(CBLAS_ORDER order, CBLAS_TRANSPOSE trans, int M, int N,
                        float alpha, const float* A, int lda, const float* x,
                        int incX, float beta, float* y, int incY) {
  using namespace Eigen;

  if (order == CblasRowMajor) {
    Map<const Matrix<float, Dynamic, Dynamic, RowMajor>> matA(A, M, N);
    int xSize = (trans == CblasNoTrans) ? N : M;
    int ySize = (trans == CblasNoTrans) ? M : N;
    Map<const VectorXf, 0, InnerStride<>> vecX(x, xSize, InnerStride<>(incX));
    Map<VectorXf, 0, InnerStride<>> vecY(y, ySize, InnerStride<>(incY));

    if (trans == CblasNoTrans) {
      vecY = alpha * matA * vecX + beta * vecY;
    } else {
      vecY = alpha * matA.transpose() * vecX + beta * vecY;
    }
  } else {
    Map<const Matrix<float, Dynamic, Dynamic, ColMajor>> matA(A, M, N);
    int xSize = (trans == CblasNoTrans) ? N : M;
    int ySize = (trans == CblasNoTrans) ? M : N;
    Map<const VectorXf, 0, InnerStride<>> vecX(x, xSize, InnerStride<>(incX));
    Map<VectorXf, 0, InnerStride<>> vecY(y, ySize, InnerStride<>(incY));

    if (trans == CblasNoTrans) {
      vecY = alpha * matA * vecX + beta * vecY;
    } else {
      vecY = alpha * matA.transpose() * vecX + beta * vecY;
    }
  }
}

// SDOT: Single-precision dot product
inline float cblas_sdot(int N, const float* x, int incX, const float* y,
                        int incY) {
  using namespace Eigen;
  Map<const VectorXf, 0, InnerStride<>> vecX(x, N, InnerStride<>(incX));
  Map<const VectorXf, 0, InnerStride<>> vecY(y, N, InnerStride<>(incY));
  return vecX.dot(vecY);
}

// SAXPY: y = alpha * x + y
inline void cblas_saxpy(int N, float alpha, const float* x, int incX, float* y,
                        int incY) {
  using namespace Eigen;
  Map<const VectorXf, 0, InnerStride<>> vecX(x, N, InnerStride<>(incX));
  Map<VectorXf, 0, InnerStride<>> vecY(y, N, InnerStride<>(incY));
  vecY += alpha * vecX;
}

// SSCAL: x = alpha * x
inline void cblas_sscal(int N, float alpha, float* x, int incX) {
  using namespace Eigen;
  Map<VectorXf, 0, InnerStride<>> vecX(x, N, InnerStride<>(incX));
  vecX *= alpha;
}

#ifdef __cplusplus
}
#endif

#endif  // CBLAS_EIGEN_H

