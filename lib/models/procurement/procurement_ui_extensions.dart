import 'package:flutter/material.dart';
import 'package:ndu_project/models/procurement/procurement_models.dart';

extension ProcurementItemStatusUI on ProcurementItemStatus {
  String get label {
    switch (this) {
      case ProcurementItemStatus.planning:
        return 'Planning';
      case ProcurementItemStatus.rfqReview:
        return 'RFQ Review';
      case ProcurementItemStatus.vendorSelection:
        return 'Vendor Selection';
      case ProcurementItemStatus.ordered:
        return 'Ordered';
      case ProcurementItemStatus.delivered:
        return 'Delivered';
      case ProcurementItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ProcurementItemStatus.planning:
        return const Color(0xFFEFF6FF);
      case ProcurementItemStatus.rfqReview:
        return const Color(0xFFFFF7ED);
      case ProcurementItemStatus.vendorSelection:
        return const Color(0xFFEFF6FF);
      case ProcurementItemStatus.ordered:
        return const Color(0xFFF1F5F9);
      case ProcurementItemStatus.delivered:
        return const Color(0xFFE8FFF4);
      case ProcurementItemStatus.cancelled:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get textColor {
    switch (this) {
      case ProcurementItemStatus.planning:
        return const Color(0xFF2563EB);
      case ProcurementItemStatus.rfqReview:
        return const Color(0xFFEA580C);
      case ProcurementItemStatus.vendorSelection:
        return const Color(0xFF2563EB);
      case ProcurementItemStatus.ordered:
        return const Color(0xFF1F2937);
      case ProcurementItemStatus.delivered:
        return const Color(0xFF047857);
      case ProcurementItemStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }

  Color get borderColor {
    switch (this) {
      case ProcurementItemStatus.planning:
      case ProcurementItemStatus.vendorSelection:
        return const Color(0xFFBFDBFE);
      case ProcurementItemStatus.rfqReview:
        return const Color(0xFFFECF8F);
      case ProcurementItemStatus.ordered:
        return const Color(0xFFE2E8F0);
      case ProcurementItemStatus.delivered:
        return const Color(0xFFBBF7D0);
      case ProcurementItemStatus.cancelled:
        return const Color(0xFFE2E8F0);
    }
  }
}

extension ProcurementPriorityUI on ProcurementPriority {
  String get label {
    switch (this) {
      case ProcurementPriority.low:
        return 'Low';
      case ProcurementPriority.medium:
        return 'Medium';
      case ProcurementPriority.high:
        return 'High';
      case ProcurementPriority.critical:
        return 'Critical';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ProcurementPriority.critical:
        return const Color(0xFFFFF1F2);
      case ProcurementPriority.high:
        return const Color(0xFFEFF6FF);
      case ProcurementPriority.medium:
        return const Color(0xFFF8FAFC);
      case ProcurementPriority.low:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get textColor {
    switch (this) {
      case ProcurementPriority.critical:
        return const Color(0xFFDC2626);
      case ProcurementPriority.high:
        return const Color(0xFF1D4ED8);
      case ProcurementPriority.medium:
        return const Color(0xFF475569);
      case ProcurementPriority.low:
        return const Color(0xFF4B5563);
    }
  }

  Color get borderColor {
    switch (this) {
      case ProcurementPriority.critical:
        return const Color(0xFFFECACA);
      case ProcurementPriority.high:
        return const Color(0xFFBFDBFE);
      case ProcurementPriority.medium:
        return const Color(0xFFE2E8F0);
      case ProcurementPriority.low:
        return const Color(0xFFE2E8F0);
    }
  }
}

extension RfqStatusUI on RfqStatus {
  String get label {
    switch (this) {
      case RfqStatus.draft:
        return 'Draft';
      case RfqStatus.review:
        return 'Review';
      case RfqStatus.inMarket:
        return 'In Market';
      case RfqStatus.evaluation:
        return 'Evaluation';
      case RfqStatus.awarded:
        return 'Awarded';
      case RfqStatus.closed:
        return 'Closed';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RfqStatus.draft:
        return const Color(0xFFF1F5F9);
      case RfqStatus.review:
        return const Color(0xFFFFF7ED);
      case RfqStatus.inMarket:
        return const Color(0xFFEFF6FF);
      case RfqStatus.evaluation:
        return const Color(0xFFF5F3FF);
      case RfqStatus.awarded:
        return const Color(0xFFE8FFF4);
      case RfqStatus.closed:
        return const Color(0xFFE2E8F0);
    }
  }

  Color get textColor {
    switch (this) {
      case RfqStatus.draft:
        return const Color(0xFF64748B);
      case RfqStatus.review:
        return const Color(0xFFF97316);
      case RfqStatus.inMarket:
        return const Color(0xFF2563EB);
      case RfqStatus.evaluation:
        return const Color(0xFF6D28D9);
      case RfqStatus.awarded:
        return const Color(0xFF047857);
      case RfqStatus.closed:
        return const Color(0xFF475569);
    }
  }

  Color get borderColor {
    switch (this) {
      case RfqStatus.draft:
        return const Color(0xFFE2E8F0);
      case RfqStatus.review:
        return const Color(0xFFFED7AA);
      case RfqStatus.inMarket:
        return const Color(0xFFBFDBFE);
      case RfqStatus.evaluation:
        return const Color(0xFFE9D5FF);
      case RfqStatus.awarded:
        return const Color(0xFFBBF7D0);
      case RfqStatus.closed:
        return const Color(0xFFE2E8F0);
    }
  }
}

extension PurchaseOrderStatusUI on PurchaseOrderStatus {
  String get label {
    switch (this) {
      case PurchaseOrderStatus.awaitingApproval:
        return 'Awaiting Approval';
      case PurchaseOrderStatus.issued:
        return 'Issued';
      case PurchaseOrderStatus.inTransit:
        return 'In Transit';
      case PurchaseOrderStatus.received:
        return 'Received';
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PurchaseOrderStatus.awaitingApproval:
        return const Color(0xFFFFF7ED);
      case PurchaseOrderStatus.issued:
        return const Color(0xFFEFF6FF);
      case PurchaseOrderStatus.inTransit:
        return const Color(0xFFF5F3FF);
      case PurchaseOrderStatus.received:
        return const Color(0xFFE8FFF4);
      case PurchaseOrderStatus.draft:
        return const Color(0xFFF1F5F9);
      case PurchaseOrderStatus.cancelled:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get textColor {
    switch (this) {
      case PurchaseOrderStatus.awaitingApproval:
        return const Color(0xFFF97316);
      case PurchaseOrderStatus.issued:
        return const Color(0xFF2563EB);
      case PurchaseOrderStatus.inTransit:
        return const Color(0xFF6D28D9);
      case PurchaseOrderStatus.received:
        return const Color(0xFF047857);
      case PurchaseOrderStatus.draft:
        return const Color(0xFF475569);
      case PurchaseOrderStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }

  Color get borderColor {
    switch (this) {
      case PurchaseOrderStatus.awaitingApproval:
        return const Color(0xFFFED7AA);
      case PurchaseOrderStatus.issued:
        return const Color(0xFFBFDBFE);
      case PurchaseOrderStatus.inTransit:
        return const Color(0xFFE9D5FF);
      case PurchaseOrderStatus.received:
        return const Color(0xFFBBF7D0);
      case PurchaseOrderStatus.draft:
        return const Color(0xFFE2E8F0);
      case PurchaseOrderStatus.cancelled:
        return const Color(0xFFE2E8F0);
    }
  }
}
