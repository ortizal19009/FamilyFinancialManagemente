import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-investments',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './investments.html',
  styleUrl: './investments.scss'
})
export class InvestmentsComponent implements OnInit {
  private apiService = inject(ApiService);

  investments: any[] = [];
  loading = false;
  successMsg = '';
  errorMsg = '';
  editingInvestmentId: number | null = null;

  formInvestment = this.createEmptyInvestment();

  ngOnInit() {
    this.loadInvestments();
  }

  loadInvestments() {
    this.apiService.getInvestments().subscribe(data => {
      this.investments = data;
    });
  }

  onSubmit() {
    this.loading = true;
    const request$ = this.editingInvestmentId === null
      ? this.apiService.createInvestment(this.formInvestment)
      : this.apiService.updateInvestment(this.editingInvestmentId, this.formInvestment);

    request$.subscribe({
      next: () => {
        this.successMsg = this.editingInvestmentId === null
          ? 'Inversión registrada correctamente'
          : 'Inversión actualizada correctamente';
        this.resetForm();
        this.loadInvestments();
        this.loading = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al guardar la inversión';
        this.loading = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onEdit(investment: any) {
    this.editingInvestmentId = investment.id;
    this.formInvestment = {
      institution: investment.institution ?? '',
      investment_type: investment.investment_type ?? 'Cooperativa',
      title: investment.title ?? '',
      owner: investment.owner ?? '',
      invested_amount: investment.invested_amount ?? 0,
      current_value: investment.current_value ?? 0,
      expected_return_rate: investment.expected_return_rate ?? 0,
      start_date: investment.start_date ?? '',
      end_date: investment.end_date ?? '',
      status: investment.status ?? 'activa',
      notes: investment.notes ?? ''
    };
  }

  onDelete(investment: any) {
    const confirmed = window.confirm(`¿Deseas eliminar la inversión "${investment.title}"?`);
    if (!confirmed) {
      return;
    }

    this.apiService.deleteInvestment(investment.id).subscribe({
      next: () => {
        this.successMsg = 'Inversión eliminada correctamente';
        if (this.editingInvestmentId === investment.id) {
          this.resetForm();
        }
        this.loadInvestments();
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al eliminar la inversión';
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onCancelEdit() {
    this.resetForm();
  }

  getTotalInvested(): number {
    return this.investments.reduce((sum, item) => sum + Number(item.invested_amount || 0), 0);
  }

  getTotalCurrentValue(): number {
    return this.investments.reduce((sum, item) => sum + Number(item.current_value || 0), 0);
  }

  getTotalProfitLoss(): number {
    return this.investments.reduce((sum, item) => sum + Number(item.profit_loss || 0), 0);
  }

  private resetForm() {
    this.editingInvestmentId = null;
    this.formInvestment = this.createEmptyInvestment();
  }

  private createEmptyInvestment() {
    return {
      institution: '',
      investment_type: 'Cooperativa',
      title: '',
      owner: '',
      invested_amount: 0,
      current_value: 0,
      expected_return_rate: 0,
      start_date: new Date().toISOString().split('T')[0],
      end_date: '',
      status: 'activa',
      notes: ''
    };
  }
}
