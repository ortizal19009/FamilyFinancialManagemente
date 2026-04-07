import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-debtors',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './debtors.html',
  styleUrl: './debtors.scss'
})
export class DebtorsComponent implements OnInit {
  private apiService = inject(ApiService);

  debtors: any[] = [];
  smallDebts: any[] = [];
  editingDebtorId: number | null = null;
  editingSmallDebtId: number | null = null;

  newDebtor = {
    name: '',
    amount_owed: 0,
    description: '',
    due_date: '',
    status: 'pendiente'
  };

  newSmallDebt = {
    lender_name: '',
    amount: 0,
    description: '',
    borrowed_date: '',
    due_date: '',
    status: 'pendiente'
  };

  loadingDebtor = false;
  loadingSmallDebt = false;
  successMsg = '';
  errorMsg = '';

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getDebtors().subscribe(data => {
      this.debtors = data;
    });
    this.apiService.getSmallDebts().subscribe(data => {
      this.smallDebts = data;
    });
  }

  onSubmitDebtor() {
    this.loadingDebtor = true;
    const request = this.editingDebtorId === null
      ? this.apiService.createDebtor(this.newDebtor)
      : this.apiService.updateDebtorStatus(this.editingDebtorId, this.newDebtor);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingDebtorId === null
          ? 'Deudor registrado correctamente'
          : 'Deudor actualizado correctamente';
        this.resetDebtorForm();
        this.loadData();
        this.loadingDebtor = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingDebtorId === null
          ? 'Error al registrar al deudor'
          : 'Error al actualizar al deudor';
        this.loadingDebtor = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onSubmitSmallDebt() {
    this.loadingSmallDebt = true;
    const request = this.editingSmallDebtId === null
      ? this.apiService.createSmallDebt(this.newSmallDebt)
      : this.apiService.updateSmallDebt(this.editingSmallDebtId, this.newSmallDebt);

    request.subscribe({
      next: () => {
        this.successMsg = this.editingSmallDebtId === null
          ? 'Deuda registrada correctamente'
          : 'Deuda actualizada correctamente';
        this.resetSmallDebtForm();
        this.loadData();
        this.loadingSmallDebt = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = this.editingSmallDebtId === null
          ? 'Error al registrar la deuda'
          : 'Error al actualizar la deuda';
        this.loadingSmallDebt = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditDebtor(debtor: any) {
    this.editingDebtorId = debtor.id;
    this.newDebtor = {
      name: debtor.name ?? '',
      amount_owed: debtor.amount_owed ?? 0,
      description: debtor.description ?? '',
      due_date: debtor.due_date ?? '',
      status: debtor.status ?? 'pendiente'
    };
  }

  onDeleteDebtor(debtor: any) {
    if (!confirm(`¿Deseas eliminar a "${debtor.name}"?`)) {
      return;
    }

    this.apiService.deleteDebtor(debtor.id).subscribe({
      next: () => {
        if (this.editingDebtorId === debtor.id) {
          this.resetDebtorForm();
        }
        this.successMsg = 'Deudor eliminado correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar al deudor';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEditSmallDebt(debt: any) {
    this.editingSmallDebtId = debt.id;
    this.newSmallDebt = {
      lender_name: debt.lender_name ?? '',
      amount: debt.amount ?? 0,
      description: debt.description ?? '',
      borrowed_date: debt.borrowed_date ?? '',
      due_date: debt.due_date ?? '',
      status: debt.status ?? 'pendiente'
    };
  }

  onDeleteSmallDebt(debt: any) {
    if (!confirm(`¿Deseas eliminar la deuda con "${debt.lender_name}"?`)) {
      return;
    }

    this.apiService.deleteSmallDebt(debt.id).subscribe({
      next: () => {
        if (this.editingSmallDebtId === debt.id) {
          this.resetSmallDebtForm();
        }
        this.successMsg = 'Deuda eliminada correctamente';
        this.loadData();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al eliminar la deuda';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  resetDebtorForm() {
    this.editingDebtorId = null;
    this.newDebtor = {
      name: '',
      amount_owed: 0,
      description: '',
      due_date: '',
      status: 'pendiente'
    };
  }

  resetSmallDebtForm() {
    this.editingSmallDebtId = null;
    this.newSmallDebt = {
      lender_name: '',
      amount: 0,
      description: '',
      borrowed_date: '',
      due_date: '',
      status: 'pendiente'
    };
  }

  getTotalOwed(): number {
    return this.debtors
      .filter(d => d.status === 'pendiente')
      .reduce((acc, curr) => acc + curr.amount_owed, 0);
  }

  getTotalSmallDebts(): number {
    return this.smallDebts
      .filter(d => d.status === 'pendiente')
      .reduce((acc, curr) => acc + curr.amount, 0);
  }
}
